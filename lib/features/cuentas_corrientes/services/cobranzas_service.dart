import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para manejar operaciones de cobranzas
class CobranzasService {
  final SupabaseClient _supabase;

  CobranzasService(this._supabase);

  /// Genera un nuevo recibo de cobranza usando una función PostgreSQL transaccional
  ///
  /// Parámetros:
  /// - socioId: ID del socio
  /// - transaccionesAPagar: Map de idTransaccion -> monto a pagar
  /// - formasPago: Map de idConceptoTesoreria -> monto
  /// - operadorId: ID del operador que registra (opcional)
  ///
  /// Retorna el número de recibo generado
  /// NOTA: El asiento de diario debe generarse por separado usando AsientosService
  /// Obtiene el próximo número de recibo sugerido sin consumirlo
  Future<int> peekNextNumeroRecibo() async {
    final response = await _supabase.rpc('peek_next_numero', params: {
      'p_tipo': 'RECIBO',
    });
    return response as int;
  }

  Future<int> generarRecibo({
    int? socioId,
    int? profesionalId,
    required Map<int, double> transaccionesAPagar,
    required Map<int, double> formasPago,
    int? operadorId,
    int? numeroRecibo,
  }) async {
    assert(socioId != null || profesionalId != null,
        'Debe proveer socioId o profesionalId');

    // Validar que los totales coincidan
    final totalAPagar = transaccionesAPagar.values.fold(0.0, (a, b) => a + b);
    final totalFormasPago = formasPago.values.fold(0.0, (a, b) => a + b);

    if ((totalAPagar - totalFormasPago).abs() > 0.01) {
      throw Exception(
        'Los totales no coinciden: Total a pagar: \$${totalAPagar.toStringAsFixed(2)}, '
        'Total formas de pago: \$${totalFormasPago.toStringAsFixed(2)}'
      );
    }

    // Preparar los datos en formato JSON para la función PostgreSQL
    final transaccionesJson = transaccionesAPagar.entries
        .map((e) => {'id_transaccion': e.key, 'monto': e.value})
        .toList();

    final formasPagoJson = formasPago.entries
        .map((e) => {'id_concepto': e.key, 'monto': e.value})
        .toList();

    try {
      // Llamar a la función PostgreSQL que maneja todo de forma transaccional
      final response = await _supabase.rpc('generar_recibo_cobranza', params: {
        'p_socio_id': socioId,
        'p_profesional_id': profesionalId,
        'p_transacciones_a_pagar': transaccionesJson,
        'p_formas_pago': formasPagoJson,
        'p_operador_id': operadorId,
        'p_numero_recibo': numeroRecibo,
      });

      if (response == null || (response as List).isEmpty) {
        throw Exception('Error al generar recibo: respuesta vacía');
      }

      // La función retorna una fila con numero_recibo e ids_valores_creados
      final resultado = response.first;
      final nroRecibo = resultado['numero_recibo'] as int;

      return nroRecibo;
    } catch (e) {
      // Si hay error, la transacción en PostgreSQL hace rollback automático
      rethrow;
    }
  }

  /// Genera un asiento de diario contable (placeholder)
  Future<void> generarAsientoDiario({
    required int numeroRecibo,
    required int socioId,
    required Map<int, double> formasPago,
    required double total,
  }) async {
    // TODO: Implementar la lógica de generación de asiento contable
    // Esto dependerá de la estructura de la tabla de asientos y del plan de cuentas

    // Ejemplo de estructura:
    // - Debe: Caja/Banco (según forma de pago)
    // - Haber: Cuenta del socio / Deudores por venta

    throw UnimplementedError('Generación de asiento de diario pendiente de implementar');
  }

  /// Da de baja un recibo con rollback atómico vía función PostgreSQL.
  Future<void> anularRecibo(
    int numeroRecibo, {
    required String motivo,
    int? operadorId,
  }) async {
    await _supabase.rpc('anular_recibo_cobranza', params: {
      'p_numero_recibo': numeroRecibo,
      'p_motivo': motivo,
      'p_operador_id': operadorId,
    });
  }

  /// Obtiene el detalle de un recibo
  Future<Map<String, dynamic>> getDetalleRecibo(int numeroRecibo) async {
    // Obtener valores de tesorería del recibo
    final valores = await _supabase
        .from('valores_tesoreria')
        .select('*, conceptos_tesoreria(*)')
        .eq('numero_interno', numeroRecibo);

    return {
      'numero_recibo': numeroRecibo,
      'valores': valores,
      'total': valores.fold(0.0, (sum, v) => sum + ((v['importe'] as num?)?.toDouble() ?? 0.0)),
    };
  }
}
