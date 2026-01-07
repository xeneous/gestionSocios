import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/socio_deuda_item.dart';

/// Clase auxiliar temporal para agrupar deudas por socio
class _SocioDeudaTemp {
  final int socioId;
  final String apellido;
  final String nombre;
  final String? email;
  final bool adheridoDebito;
  final int? tarjetaId;
  final List<DeudaDetalle> deudas = [];

  _SocioDeudaTemp({
    required this.socioId,
    required this.apellido,
    required this.nombre,
    this.email,
    required this.adheridoDebito,
    this.tarjetaId,
  });
}

class SeguimientoDeudasService {
  final SupabaseClient _supabase;

  SeguimientoDeudasService(this._supabase);

  /// Obtiene los socios con deudas según los filtros
  ///
  /// OPTIMIZACIÓN: Usa una función RPC de PostgreSQL para hacer el cálculo en el servidor
  /// en lugar de traer todos los registros y procesarlos en el cliente.
  ///
  /// Parámetros:
  /// - [mesesImpagos]: Cantidad de meses impagos
  /// - [soloDebitoAutomatico]: Si es true, solo socios con débito automático
  /// - [tarjetaId]: Filtrar por tarjeta específica (solo si soloDebitoAutomatico = true)
  /// - [mesesOMas]: Si es true, busca >= mesesImpagos, si es false busca == mesesImpagos
  /// - [limit]: Cantidad de registros a obtener (null = todos)
  /// - [offset]: Número de registros a saltar
  Future<Map<String, dynamic>> buscarSociosConDeuda({
    required int mesesImpagos,
    required bool soloDebitoAutomatico,
    int? tarjetaId,
    bool mesesOMas = true,
    int? limit,
    int offset = 0,
  }) async {
    try {
      // Llamar a la función RPC que hace el procesamiento en el servidor
      final response = await _supabase.rpc(
        'buscar_socios_con_deuda',
        params: {
          'p_meses_impagos': mesesImpagos,
          'p_solo_debito_automatico': soloDebitoAutomatico,
          'p_tarjeta_id': tarjetaId,
          'p_meses_o_mas': mesesOMas,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final rows = response as List;

      int totalCount = 0;
      final sociosConDeuda = <SocioDeudaItem>[];

      for (final row in rows) {
        // El total_count viene en cada fila, tomamos el de la primera
        if (totalCount == 0 && row['total_count'] != null) {
          totalCount = (row['total_count'] as num).toInt();
        }

        // Parsear los detalles desde el JSON
        final detallesJson = row['detalles'] as List;
        final detalles = detallesJson.map((d) {
          return DeudaDetalle(
            documentoNumero: d['documento_numero'] as String,
            importe: (d['importe'] as num).toDouble(),
            vencimiento: d['vencimiento'] != null
                ? DateTime.parse(d['vencimiento'] as String)
                : null,
          );
        }).toList();

        sociosConDeuda.add(SocioDeudaItem(
          socioId: row['socio_id'] as int,
          apellido: row['apellido'] as String,
          nombre: row['nombre'] as String,
          mesesMora: row['meses_mora'] as int,
          importeTotal: (row['importe_total'] as num).toDouble(),
          email: row['email'] as String?,
          adheridoDebito: row['adherido_debito'] as bool,
          tarjetaId: row['tarjeta_id'] as int?,
          detalles: detalles,
        ));
      }

      return {
        'items': sociosConDeuda,
        'totalCount': totalCount,
      };
    } catch (e) {
      // Si la función RPC no existe, usar el método anterior (fallback)
      print('Error al llamar RPC: $e');
      final items = await _buscarSociosConDeudaLegacy(
        mesesImpagos: mesesImpagos,
        soloDebitoAutomatico: soloDebitoAutomatico,
        tarjetaId: tarjetaId,
        mesesOMas: mesesOMas,
      );
      return {
        'items': items,
        'totalCount': items.length,
      };
    }
  }

  /// Obtiene TODOS los socios con deudas sin paginación (para exportar)
  Future<List<SocioDeudaItem>> buscarSociosConDeudaCompleto({
    required int mesesImpagos,
    required bool soloDebitoAutomatico,
    int? tarjetaId,
    bool mesesOMas = true,
  }) async {
    final result = await buscarSociosConDeuda(
      mesesImpagos: mesesImpagos,
      soloDebitoAutomatico: soloDebitoAutomatico,
      tarjetaId: tarjetaId,
      mesesOMas: mesesOMas,
      limit: null,
      offset: 0,
    );
    return result['items'] as List<SocioDeudaItem>;
  }

  /// Método legacy (backup) - procesa en el cliente
  Future<List<SocioDeudaItem>> _buscarSociosConDeudaLegacy({
    required int mesesImpagos,
    required bool soloDebitoAutomatico,
    int? tarjetaId,
    bool mesesOMas = true,
  }) async {
    // Obtener todos los movimientos con paginación (límite de Supabase: 1000 registros)
    final movimientos = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int offset = 0;
    bool hasMore = true;

    while (hasMore) {
      // Query eficiente: obtener cuentas corrientes con saldo pendiente y datos del socio
      var query = _supabase
          .from('cuentas_corrientes')
          .select('''
            socio_id,
            documento_numero,
            importe,
            cancelado,
            vencimiento,
            socios!inner(
              id,
              apellido,
              nombre,
              email,
              adherido_debito,
              tarjeta_id
            )
          ''');

      // Filtrar por débito automático si es necesario
      if (soloDebitoAutomatico) {
        query = query.eq('socios.adherido_debito', true);

        if (tarjetaId != null) {
          query = query.eq('socios.tarjeta_id', tarjetaId);
        }
      }

      final response = await query
          .order('socio_id')
          .order('documento_numero')
          .range(offset, offset + pageSize - 1);

      final rows = response as List;
      movimientos.addAll(rows.cast<Map<String, dynamic>>());

      hasMore = rows.length == pageSize;
      offset += pageSize;
    }

    // Agrupar por socio y calcular deudas
    final sociosDeudasMap = <int, _SocioDeudaTemp>{};

    for (final mov in movimientos) {
      final socioData = mov['socios'];
      final socioId = socioData['id'] as int;
      final importe = (mov['importe'] as num?)?.toDouble() ?? 0.0;
      final cancelado = (mov['cancelado'] as num?)?.toDouble() ?? 0.0;
      final saldo = importe - cancelado;

      // Solo procesar si tiene saldo pendiente
      if (saldo > 0) {
        // Crear o actualizar el registro del socio
        if (!sociosDeudasMap.containsKey(socioId)) {
          sociosDeudasMap[socioId] = _SocioDeudaTemp(
            socioId: socioId,
            apellido: socioData['apellido'] as String,
            nombre: socioData['nombre'] as String,
            email: socioData['email'] as String?,
            adheridoDebito: socioData['adherido_debito'] as bool? ?? false,
            tarjetaId: socioData['tarjeta_id'] as int?,
          );
        }

        // Agregar el detalle de la deuda
        sociosDeudasMap[socioId]!.deudas.add(DeudaDetalle(
          documentoNumero: mov['documento_numero'] as String,
          importe: saldo,
          vencimiento: mov['vencimiento'] != null
              ? DateTime.parse(mov['vencimiento'] as String)
              : null,
        ));
      }
    }

    // Filtrar por cantidad de meses impagos y convertir a lista
    final sociosConDeuda = <SocioDeudaItem>[];

    for (final temp in sociosDeudasMap.values) {
      // Aplicar filtro según mesesOMas
      final matchesFilter = mesesOMas
          ? temp.deudas.length >= mesesImpagos  // "o más"
          : temp.deudas.length == mesesImpagos; // exacto

      if (matchesFilter) {
        final importeTotal = temp.deudas.fold<double>(
          0,
          (sum, deuda) => sum + deuda.importe,
        );

        sociosConDeuda.add(SocioDeudaItem(
          socioId: temp.socioId,
          apellido: temp.apellido,
          nombre: temp.nombre,
          mesesMora: temp.deudas.length,
          importeTotal: importeTotal,
          email: temp.email,
          adheridoDebito: temp.adheridoDebito,
          tarjetaId: temp.tarjetaId,
          detalles: temp.deudas,
        ));
      }
    }

    // Ordenar por cantidad de meses mora (descendente)
    sociosConDeuda.sort((a, b) => b.mesesMora.compareTo(a.mesesMora));

    return sociosConDeuda;
  }

  /// Envía notificación de deuda a un socio
  /// TODO: Implementar envío de email
  Future<void> enviarNotificacion({
    required int socioId,
    required String email,
    required List<DeudaDetalle> deudas,
  }) async {
    // TODO: Implementar lógica de envío de email
    // Por ahora solo simular
    await Future.delayed(const Duration(milliseconds: 500));

    // Aquí se podría:
    // 1. Llamar a una Cloud Function de Firebase
    // 2. Usar un servicio de email (SendGrid, etc.)
    // 3. Registrar la notificación en una tabla de log

    print('Notificación enviada a $email para socio $socioId');
  }
}
