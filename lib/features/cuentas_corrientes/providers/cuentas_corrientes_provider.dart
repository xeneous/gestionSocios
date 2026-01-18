import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cuenta_corriente_model.dart';
import '../models/detalle_cuenta_corriente_model.dart';
import '../models/cuenta_corriente_completa_model.dart';
import '../services/cuentas_corrientes_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// ============================================================================
// SEARCH PARAMS
// ============================================================================

class CuentasCorrientesSearchParams {
  final int? socioId;
  final int? entidadId;
  final String? tipoComprobante;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final bool? soloPendientes; // Solo con saldo > 0

  CuentasCorrientesSearchParams({
    this.socioId,
    this.entidadId,
    this.tipoComprobante,
    this.fechaDesde,
    this.fechaHasta,
    this.soloPendientes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CuentasCorrientesSearchParams &&
          runtimeType == other.runtimeType &&
          socioId == other.socioId &&
          entidadId == other.entidadId &&
          tipoComprobante == other.tipoComprobante &&
          fechaDesde == other.fechaDesde &&
          fechaHasta == other.fechaHasta &&
          soloPendientes == other.soloPendientes;

  @override
  int get hashCode =>
      socioId.hashCode ^
      entidadId.hashCode ^
      tipoComprobante.hashCode ^
      fechaDesde.hashCode ^
      fechaHasta.hashCode ^
      soloPendientes.hashCode;
}

// ============================================================================
// SEARCH PROVIDER
// ============================================================================

final cuentasCorrientesSearchProvider = FutureProvider.family<
    List<CuentaCorrienteCompleta>, CuentasCorrientesSearchParams>(
  (ref, params) async {
    final supabase = ref.watch(supabaseProvider);

    // Query con joins para traer info relacionada
    // NOTA: Sin !inner porque PostgREST no resuelve bien los INNER JOINs
    var query = supabase.from('cuentas_corrientes').select('''
          *,
          socios(apellido, nombre),
          entidades(descripcion),
          tipos_comprobante_socios(descripcion, signo)
        ''');

    // Aplicar filtros
    if (params.socioId != null) {
      query = query.eq('socio_id', params.socioId!);
    }

    if (params.entidadId != null) {
      query = query.eq('entidad_id', params.entidadId!);
    }

    if (params.tipoComprobante != null) {
      query = query.eq('tipo_comprobante', params.tipoComprobante!);
    }

    if (params.fechaDesde != null) {
      query = query.gte(
          'fecha', params.fechaDesde!.toIso8601String().split('T')[0]);
    }

    if (params.fechaHasta != null) {
      query = query.lte(
          'fecha', params.fechaHasta!.toIso8601String().split('T')[0]);
    }

    // Ordenar por fecha ascendente
    final headersResponse = await query.order('fecha', ascending: true);

    final headers = (headersResponse as List).map((json) {
      final header = CuentaCorriente.fromJson(json);

      // Agregar información de joins
      if (json['socios'] != null) {
        header.socioNombre =
            '${json['socios']['apellido']}, ${json['socios']['nombre']}';
      }
      if (json['entidades'] != null) {
        header.entidadDescripcion = json['entidades']['descripcion'];
      }
      if (json['tipos_comprobante_socios'] != null) {
        header.tipoComprobanteDescripcion =
            json['tipos_comprobante_socios']['descripcion'];
        header.signo = json['tipos_comprobante_socios']['signo'] as int?;
      }

      return header;
    }).toList();

    // Filtrar solo pendientes si se solicita
    List<CuentaCorriente> headersFiltered = headers;
    if (params.soloPendientes == true) {
      headersFiltered = headers.where((h) => !h.estaCancelado).toList();
    }

    // Si no hay headers, retornar vacío
    if (headersFiltered.isEmpty) {
      return [];
    }

    // Obtener todos los items de una sola vez (mucho más eficiente)
    final idtransacciones =
        headersFiltered.map((h) => h.idtransaccion!).toList();

    final allItemsResponse = await supabase
        .from('detalle_cuentas_corrientes')
        .select('''
          *,
          conceptos!inner(descripcion, modalidad, grupo)
        ''')
        .inFilter('idtransaccion', idtransacciones)
        .order('idtransaccion', ascending: true)
        .order('item', ascending: true);

    // Agrupar items por idtransaccion
    final Map<int, List<DetalleCuentaCorriente>> itemsByTransaccion = {};

    for (final json in (allItemsResponse as List)) {
      final item = DetalleCuentaCorriente.fromJson(json);

      // Agregar info del concepto
      if (json['conceptos'] != null) {
        item.conceptoDescripcion = json['conceptos']['descripcion'];
        item.modalidad = json['conceptos']['modalidad'];
        item.grupo = json['conceptos']['grupo'];
      }

      final idtransaccion = item.idtransaccion;
      if (!itemsByTransaccion.containsKey(idtransaccion)) {
        itemsByTransaccion[idtransaccion] = [];
      }
      itemsByTransaccion[idtransaccion]!.add(item);
    }

    // Crear las cuentas completas
    final cuentasCompletas = headersFiltered.map((header) {
      return CuentaCorrienteCompleta(
        header: header,
        items: itemsByTransaccion[header.idtransaccion] ?? [],
      );
    }).toList();

    return cuentasCompletas;
  },
);

// ============================================================================
// PROVIDER POR SOCIO (útil para mostrar en perfil de socio)
// ============================================================================

final cuentasCorrientesPorSocioProvider =
    FutureProvider.family<List<CuentaCorrienteCompleta>, int>(
        (ref, socioId) async {
  return ref.watch(cuentasCorrientesSearchProvider(
    CuentasCorrientesSearchParams(socioId: socioId),
  ).future);
});

// ============================================================================
// NOTIFIER PARA CRUD
// ============================================================================

class CuentasCorrientesNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  /// Crear nueva cuenta corriente con sus detalles
  Future<int> createCuentaCorriente(
      CuentaCorrienteCompleta cuentaCompleta) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);
      final user = ref.read(currentUserProvider);

      // Validar datos
      if (!cuentaCompleta.isValid) {
        throw Exception(
            'El total de items (${cuentaCompleta.totalItems.toStringAsFixed(2)}) '
            'no coincide con el importe del header (${cuentaCompleta.header.importe?.toStringAsFixed(2)})');
      }

      if (cuentaCompleta.items.isEmpty) {
        throw Exception('Debe agregar al menos un item de detalle');
      }

      // Insertar header y obtener el ID generado
      final headerData = cuentaCompleta.header.toJson();
      headerData['created_by'] = user?.email;

      final headerResponse = await supabase
          .from('cuentas_corrientes')
          .insert(headerData)
          .select('idtransaccion')
          .single();

      final idtransaccion = headerResponse['idtransaccion'] as int;

      // Insertar items con el ID del header
      final itemsToInsert = cuentaCompleta.items.asMap().entries.map((entry) {
        final item = entry.value;
        final itemData = item.toJson();
        itemData['idtransaccion'] = idtransaccion;
        itemData['item'] = entry.key + 1; // Items comienzan en 1
        itemData['created_by'] = user?.email;
        return itemData;
      }).toList();

      await supabase.from('detalle_cuentas_corrientes').insert(itemsToInsert);

      // Invalidar cache
      ref.invalidate(cuentasCorrientesSearchProvider);
      ref.invalidate(
          cuentasCorrientesPorSocioProvider(cuentaCompleta.header.socioId));

      state = const AsyncValue.data(null);
      return idtransaccion;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Actualizar cuenta corriente existente
  Future<void> updateCuentaCorriente(
    int idtransaccion,
    CuentaCorrienteCompleta cuentaCompleta,
  ) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);
      final user = ref.read(currentUserProvider);

      // Validar datos
      if (!cuentaCompleta.isValid) {
        throw Exception(
            'El total de items no coincide con el importe del header');
      }

      // Actualizar header
      final headerData = cuentaCompleta.header.toJson();
      headerData['updated_by'] = user?.email;

      await supabase
          .from('cuentas_corrientes')
          .update(headerData)
          .eq('idtransaccion', idtransaccion);

      // Borrar items viejos (CASCADE automático, pero lo hacemos explícito)
      await supabase
          .from('detalle_cuentas_corrientes')
          .delete()
          .eq('idtransaccion', idtransaccion);

      // Insertar items nuevos
      final itemsToInsert = cuentaCompleta.items.asMap().entries.map((entry) {
        final item = entry.value;
        final itemData = item.toJson();
        itemData['idtransaccion'] = idtransaccion;
        itemData['item'] = entry.key + 1;
        itemData['created_by'] = user?.email;
        return itemData;
      }).toList();

      if (itemsToInsert.isNotEmpty) {
        await supabase.from('detalle_cuentas_corrientes').insert(itemsToInsert);
      }

      // Invalidar cache
      ref.invalidate(cuentasCorrientesSearchProvider);
      ref.invalidate(
          cuentasCorrientesPorSocioProvider(cuentaCompleta.header.socioId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Eliminar cuenta corriente
  Future<void> deleteCuentaCorriente(int idtransaccion, int socioId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      // DELETE CASCADE se encarga de borrar los items
      await supabase
          .from('cuentas_corrientes')
          .delete()
          .eq('idtransaccion', idtransaccion);

      // Invalidar cache
      ref.invalidate(cuentasCorrientesSearchProvider);
      ref.invalidate(cuentasCorrientesPorSocioProvider(socioId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Obtener cuenta corriente completa por ID
  Future<CuentaCorrienteCompleta?> getCuentaCorrienteById(
      int idtransaccion) async {
    try {
      final supabase = ref.read(supabaseProvider);

      // Obtener header
      final headerResponse =
          await supabase.from('cuentas_corrientes').select('''
            *,
            socios!inner(apellido, nombre),
            entidades!inner(descripcion),
            tipos_comprobante_socios!inner(descripcion, signo)
          ''').eq('idtransaccion', idtransaccion).single();

      final header = CuentaCorriente.fromJson(headerResponse);

      // Agregar info de joins
      if (headerResponse['socios'] != null) {
        header.socioNombre =
            '${headerResponse['socios']['apellido']}, ${headerResponse['socios']['nombre']}';
      }
      if (headerResponse['entidades'] != null) {
        header.entidadDescripcion = headerResponse['entidades']['descripcion'];
      }
      if (headerResponse['tipos_comprobante_socios'] != null) {
        header.tipoComprobanteDescripcion =
            headerResponse['tipos_comprobante_socios']['descripcion'];
        header.signo =
            headerResponse['tipos_comprobante_socios']['signo'] as int?;
      }

      // Obtener items
      final itemsResponse = await supabase
          .from('detalle_cuentas_corrientes')
          .select('''
            *,
            conceptos!inner(descripcion, modalidad, grupo)
          ''')
          .eq('idtransaccion', idtransaccion)
          .order('item', ascending: true);

      final items = (itemsResponse as List).map((json) {
        final item = DetalleCuentaCorriente.fromJson(json);

        if (json['conceptos'] != null) {
          item.conceptoDescripcion = json['conceptos']['descripcion'];
          item.modalidad = json['conceptos']['modalidad'];
          item.grupo = json['conceptos']['grupo'];
        }

        return item;
      }).toList();

      return CuentaCorrienteCompleta(header: header, items: items);
    } catch (e) {
      return null;
    }
  }

  /// Registrar pago/cancelación parcial o total
  Future<void> registrarPago(
      int idtransaccion, double monto, int socioId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);
      final user = ref.read(currentUserProvider);

      // Obtener cuenta corriente actual
      final cuenta = await getCuentaCorrienteById(idtransaccion);
      if (cuenta == null) {
        throw Exception('Cuenta corriente no encontrada');
      }

      final nuevoCancelado = (cuenta.header.cancelado ?? 0.0) + monto;

      // Validar que no supere el importe
      if (nuevoCancelado > cuenta.header.importe!) {
        throw Exception('El monto a pagar supera el saldo pendiente');
      }

      // Actualizar campo cancelado
      await supabase.from('cuentas_corrientes').update({
        'cancelado': nuevoCancelado,
        'updated_by': user?.email,
      }).eq('idtransaccion', idtransaccion);

      // Invalidar cache
      ref.invalidate(cuentasCorrientesSearchProvider);
      ref.invalidate(cuentasCorrientesPorSocioProvider(socioId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Obtener saldo total de un socio
  Future<Map<String, double>> getSaldoSocio(int socioId) async {
    try {
      final supabase = ref.read(supabaseProvider);

      // Obtener todas las transacciones con el signo correcto
      final response = await supabase.from('cuentas_corrientes').select('''
            importe,
            cancelado,
            tipos_comprobante_socios!inner(signo)
          ''').eq('socio_id', socioId);

      double totalDebe = 0.0;
      double totalHaber = 0.0;
      double totalCancelado = 0.0;
      int totalTransacciones = 0;

      for (final row in (response as List)) {
        final importe = (row['importe'] as num?)?.toDouble() ?? 0.0;
        final cancelado = (row['cancelado'] as num?)?.toDouble() ?? 0.0;
        final signo = row['tipos_comprobante_socios']?['signo'] as int? ?? 1;

        // signo = 1 -> débito (debe), signo = -1 -> crédito (haber)
        if (signo == 1) {
          totalDebe += importe;
        } else {
          totalHaber += importe;
        }

        totalCancelado += cancelado;
        totalTransacciones++;
      }

      final saldoTotal = totalDebe - totalHaber;
      final saldoPendiente = saldoTotal - totalCancelado;

      return {
        'saldo_total': saldoTotal,
        'total_cancelado': totalCancelado,
        'saldo_pendiente': saldoPendiente,
        'total_transacciones': totalTransacciones.toDouble(),
      };
    } catch (e) {
      return {
        'saldo_total': 0.0,
        'total_cancelado': 0.0,
        'saldo_pendiente': 0.0,
        'total_transacciones': 0.0,
      };
    }
  }
}

final cuentasCorrientesNotifierProvider =
    NotifierProvider<CuentasCorrientesNotifier, AsyncValue<void>>(() {
  return CuentasCorrientesNotifier();
});

// ============================================================================
// PROVIDER DE SALDO POR SOCIO
// ============================================================================

final saldoSocioProvider =
    FutureProvider.family<Map<String, double>, int>((ref, socioId) async {
  return ref
      .read(cuentasCorrientesNotifierProvider.notifier)
      .getSaldoSocio(socioId);
});

// ============================================================================
// PROVIDER PARA RESUMEN DE CUENTAS CORRIENTES (LISTADO CON PAGINACIÓN)
// ============================================================================

/// Provider del servicio de resumen de cuentas corrientes
final cuentasCorrientesResumenServiceProvider =
    Provider<CuentasCorrientesService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return CuentasCorrientesService(supabase);
});

/// Notifier para manejar el estado de la página actual del resumen
class ResumenPaginaNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setPagina(int pagina) {
    state = pagina;
  }

  void reset() {
    state = 0;
  }
}

/// Provider de estado para la página actual del resumen
final resumenCuentasCorrientesPaginaProvider =
    NotifierProvider<ResumenPaginaNotifier, int>(() {
  return ResumenPaginaNotifier();
});

/// Tamaño de página para resumen
const int resumenPageSize = 50;

/// Provider para obtener el resumen de cuentas corrientes paginado
final resumenCuentasCorrientesProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(cuentasCorrientesResumenServiceProvider);
  final pagina = ref.watch(resumenCuentasCorrientesPaginaProvider);

  return service.obtenerResumenCuentasCorrientes(
    limit: resumenPageSize,
    offset: pagina * resumenPageSize,
  );
});
