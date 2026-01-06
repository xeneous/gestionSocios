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

    return (response as List)
        .map((json) => Tarjeta.fromJson(json))
        .toList();
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
}
