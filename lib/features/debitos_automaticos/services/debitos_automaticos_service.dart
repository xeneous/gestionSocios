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
    // Query base: buscar movimientos pendientes del período
    var query = _supabase
        .from('cuentas_corrientes')
        .select('''
          idtransaccion,
          socio_id,
          tipo_comprobante,
          documento_numero,
          importe,
          cancelado,
          socios!inner(
            id,
            apellido,
            nombre,
            numero_tarjeta,
            tarjeta_id,
            adherido_debito
          )
        ''')
        .eq('documento_numero', anioMes.toString())
        .eq('socios.adherido_debito', true) // Solo socios adheridos a débito
        .not('socios.numero_tarjeta', 'is', null); // Que tengan tarjeta

    // Filtrar por tarjeta si se especifica
    if (tarjetaId != null) {
      query = query.eq('socios.tarjeta_id', tarjetaId);
    }

    final response = await query.order('socios(apellido)');

    final items = <DebitoAutomaticoItem>[];

    for (final row in response as List) {
      final socio = row['socios'];
      final importe = (row['importe'] as num?)?.toDouble() ?? 0.0;
      final cancelado = (row['cancelado'] as num?)?.toDouble() ?? 0.0;
      final saldo = importe - cancelado;

      // Solo incluir si tiene saldo pendiente (importe - cancelado > 0)
      if (saldo > 0) {
        items.add(DebitoAutomaticoItem(
          socioId: socio['id'] as int,
          apellido: socio['apellido'] as String,
          nombre: socio['nombre'] as String,
          numeroTarjeta: socio['numero_tarjeta'] as String?,
          importe: saldo, // El importe pendiente es el saldo
          idtransaccion: row['idtransaccion'] as int,
          tipoComprobante: row['tipo_comprobante'] as String,
          documentoNumero: row['documento_numero'] as String,
        ));
      }
    }

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
  Future<Map<String, int>> registrarPresentacionDebitoAutomatico({
    required List<DebitoAutomaticoItem> items,
    required int anioMes,
    required DateTime fechaPresentacion,
    required String nombreTarjeta,
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
      print('DEBUG: Llamando a registrar_debito_automatico');
      print('DEBUG: presentacionData = $presentacionData');
      print('DEBUG: anioMes = $anioMes');
      print('DEBUG: fechaPresentacion = ${fechaPresentacion.toIso8601String().split('T')[0]}');
      print('DEBUG: nombreTarjeta = $nombreTarjeta');

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

      print('DEBUG: Response recibida = $response');
      print('DEBUG: Response type = ${response.runtimeType}');

      if (response == null) {
        throw Exception(
            'Error al registrar débito automático: respuesta vacía');
      }

      // La función retorna JSONB: {operacion_id, numero_asiento}
      final resultado = response as Map<String, dynamic>;
      print('DEBUG: resultado = $resultado');

      return {
        'operacion_id': resultado['operacion_id'] as int,
        'numero_asiento': resultado['numero_asiento'] as int,
      };
    } catch (e) {
      print('DEBUG: Error capturado = $e');
      print('DEBUG: Error type = ${e.runtimeType}');
      // Si hay error, la transacción en PostgreSQL hace rollback automático
      rethrow;
    }
  }
}
