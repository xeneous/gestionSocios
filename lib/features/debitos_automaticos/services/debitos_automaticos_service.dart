import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tarjeta_model.dart';
import '../models/debito_automatico_item.dart';

class DebitosAutomaticosService {
  final SupabaseClient _supabase;

  DebitosAutomaticosService(this._supabase);

  /// Obtiene todas las tarjetas activas
  Future<List<Tarjeta>> getTarjetasActivas() async {
    final response = await _supabase
        .from('tarjetas')
        .select()
        .eq('activo', true)
        .order('nombre');

    return (response as List).map((json) => Tarjeta.fromJson(json)).toList();
  }

  /// Obtiene los movimientos pendientes de cuenta corriente para débito automático
  ///
  /// Parámetros:
  /// - [anioMes]: Período en formato YYYYMM (ej: 202601 para enero 2026)
  /// - [tarjetaId]: ID de la tarjeta para filtrar (null = todas)
  Future<List<DebitoAutomaticoItem>> getMovimientosPendientes({
    required int anioMes,
    int? tarjetaId,
  }) async {
    // Paso 1: Obtener socios adheridos al débito con tarjeta (paginado)
    final sociosMap = <int, Map<String, dynamic>>{};
    const sociosPageSize = 1000;
    int sociosOffset = 0;
    bool sociosHasMore = true;

    while (sociosHasMore) {
      var sociosQuery = _supabase
          .from('socios')
          .select('id, apellido, nombre, numero_tarjeta, tarjeta_id')
          .eq('adherido_debito', true)
          .not('numero_tarjeta', 'is', null);

      if (tarjetaId != null) {
        sociosQuery = sociosQuery.eq('tarjeta_id', tarjetaId);
      }

      final sociosResponse =
          await sociosQuery.range(sociosOffset, sociosOffset + sociosPageSize - 1);
      final sociosList = sociosResponse as List;

      for (final s in sociosList) {
        sociosMap[s['id'] as int] = s as Map<String, dynamic>;
      }
      sociosHasMore = sociosList.length == sociosPageSize;
      sociosOffset += sociosPageSize;
    }

    if (sociosMap.isEmpty) return [];
    final socioIds = sociosMap.keys.toList();

    // Paso 2: Obtener cuotas pendientes para esos socios y período (paginado)
    // Solo cuotas sociales (CS, CRP, CRB) con cancelado = 0
    final ccItems = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int offset = 0;
    bool hasMore = true;

    while (hasMore) {
      final ccResponse = await _supabase
          .from('cuentas_corrientes')
          .select(
              'idtransaccion, socio_id, tipo_comprobante, documento_numero, importe, cancelado')
          .eq('documento_numero', anioMes.toString())
          .inFilter('tipo_comprobante', ['CS', 'CRP', 'CRB'])
          .eq('cancelado', 0)
          .inFilter('socio_id', socioIds)
          .range(offset, offset + pageSize - 1);

      final rows = ccResponse as List;
      ccItems.addAll(rows.cast<Map<String, dynamic>>());
      hasMore = rows.length == pageSize;
      offset += pageSize;
    }

    // Paso 3: Construir items filtrando por saldo pendiente
    final items = <DebitoAutomaticoItem>[];
    for (final row in ccItems) {
      final socioId = row['socio_id'] as int;
      final socio = sociosMap[socioId];
      if (socio == null) continue;

      final importe = (row['importe'] as num?)?.toDouble() ?? 0.0;
      final cancelado = (row['cancelado'] as num?)?.toDouble() ?? 0.0;
      final saldo = importe - cancelado;

      // Solo incluir si tiene saldo pendiente (importe - cancelado > 0)
      if (saldo > 0) {
        items.add(DebitoAutomaticoItem(
          socioId: socioId,
          apellido: socio['apellido'] as String,
          nombre: socio['nombre'] as String,
          numeroTarjeta: socio['numero_tarjeta'] as String?,
          importe: saldo,
          idtransaccion: row['idtransaccion'] as int,
          tipoComprobante: row['tipo_comprobante'] as String,
          documentoNumero: row['documento_numero'] as String,
        ));
      }
    }

    // Ordenar por apellido en Dart
    items.sort((a, b) => a.apellido.compareTo(b.apellido));

    return items;
  }

  /// Obtiene estadísticas de los débitos automáticos
  Future<Map<String, dynamic>> getEstadisticas({
    required int anioMes,
    int? tarjetaId,
  }) async {
    final items = await getMovimientosPendientes(
      anioMes: anioMes,
      tarjetaId: tarjetaId,
    );

    final tarjetasValidas = items.where((item) => item.tarjetaValida).length;
    final tarjetasInvalidas = items.where((item) => !item.tarjetaValida).length;
    final totalImporte = items.fold<double>(
      0.0,
      (sum, item) => sum + item.importe,
    );

    return {
      'total_registros': items.length,
      'tarjetas_validas': tarjetasValidas,
      'tarjetas_invalidas': tarjetasInvalidas,
      'total_importe': totalImporte,
    };
  }

  /// Registra contablemente una presentación de débitos automáticos
  ///
  /// Esta función:
  /// 1. Crea un comprobante 'DA' por cada socio
  /// 2. Actualiza el campo cancelado en los CS que originaron el débito
  /// 3. Registra la trazabilidad en operaciones_contables
  /// 4. Genera el asiento contable tipo 6 (Resumen Débito Automático)
  ///
  /// Parámetros:
  /// - items: Lista de items de la presentación (agrupados por socio)
  /// - anioMes: Período de presentación (ej: 202512)
  /// - fechaPresentacion: Fecha de la presentación
  /// - nombreTarjeta: Nombre de la tarjeta (ej: 'Visa', 'Mastercard')
  /// - operadorId: ID del operador (opcional)
  ///
  /// Retorna: Map con {operacion_id, numero_asiento}
  Future<Map<String, int?>> registrarPresentacionDebitoAutomatico({
    required List<DebitoAutomaticoItem> items,
    required int anioMes,
    required DateTime fechaPresentacion,
    required String nombreTarjeta,
    required int tarjetaId,
    int? operadorId,
  }) async {
    if (items.isEmpty) {
      throw Exception('No hay items para registrar');
    }

    // Agrupar items por socio_id
    final Map<int, List<DebitoAutomaticoItem>> itemsPorSocio = {};
    for (final item in items) {
      if (!itemsPorSocio.containsKey(item.socioId)) {
        itemsPorSocio[item.socioId] = [];
      }
      itemsPorSocio[item.socioId]!.add(item);
    }

    // Construir el JSON para la función PostgreSQL
    final presentacionData = itemsPorSocio.entries.map((entry) {
      final socioId = entry.key;
      final itemsSocio = entry.value;

      // Calcular importe total para este socio
      final importeTotal = itemsSocio.fold<double>(
        0.0,
        (sum, item) => sum + item.importe,
      );

      // Construir array de transacciones
      final transacciones = itemsSocio
          .map((item) => {
                'idtransaccion': item.idtransaccion,
                'monto': item.importe,
              })
          .toList();

      return {
        'socio_id': socioId,
        'entidad_id': 0, // 0 = Socios (siempre)
        'importe_total': importeTotal,
        'transacciones': transacciones,
      };
    }).toList();

    try {
      // Llamar a la función PostgreSQL
      final response = await _supabase.rpc(
        'registrar_debito_automatico',
        params: {
          'p_presentacion_data': presentacionData,
          'p_anio_mes': anioMes,
          'p_fecha_presentacion':
              fechaPresentacion.toIso8601String().split('T')[0],
          'p_nombre_tarjeta': nombreTarjeta,
          'p_operador_id': operadorId,
        },
      );

      if (response == null) {
        throw Exception(
            'Error al registrar débito automático: respuesta vacía');
      }

      // La función retorna JSONB: {operacion_id, numero_asiento}
      final resultado = response as Map<String, dynamic>;

      // Registrar detalle por socio
      await _supabase.from('detalle_presentaciones_tarjetas').insert(
        items.map((item) => {
          'tarjeta_id': tarjetaId,
          'periodo': anioMes,
          'socio_id': item.socioId,
          'entidad_id': 0,
          'importe': item.importe,
          'numero_tarjeta': item.numeroTarjeta,
        }).toList(),
      );

      // Registrar cabecera de la presentación (totales)
      final totalImporte = items.fold<double>(0.0, (sum, item) => sum + item.importe);
      await _supabase.from('presentaciones_tarjetas').insert({
        'tarjeta_id': tarjetaId,
        'fecha_presentacion': fechaPresentacion.toIso8601String().split('T')[0],
        'total': totalImporte,
        'procesado': false, // fecha_acreditacion, comision y neto se completan después
      });

      return {
        'operacion_id': resultado['operacion_id'] as int,
        'numero_asiento': resultado['numero_asiento'] as int?,
      };
    } catch (e) {
      // Si hay error, la transacción en PostgreSQL hace rollback automático
      rethrow;
    }
  }
}
