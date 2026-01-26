import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para manejar operaciones de cobranzas de clientes/sponsors
class CobranzasClientesService {
  final SupabaseClient _supabase;

  CobranzasClientesService(this._supabase);

  /// Obtiene los comprobantes pendientes de un cliente
  Future<List<Map<String, dynamic>>> getComprobantesPendientes(int clienteId) async {
    // Primero obtener los tipos de comprobante para saber el multiplicador
    final tiposResponse = await _supabase
        .from('tip_vent_mod_header')
        .select('codigo, comprobante, descripcion, multiplicador, signo');

    final tiposMap = <int, Map<String, dynamic>>{};
    for (final tipo in tiposResponse as List) {
      tiposMap[tipo['codigo'] as int] = tipo;
    }

    // Luego obtener los comprobantes (sin join)
    final response = await _supabase
        .from('ven_cli_header')
        .select('''
          id_transaccion,
          comprobante,
          fecha,
          tipo_comprobante,
          nro_comprobante,
          tipo_factura,
          total_importe,
          cancelado,
          fecha1_venc
        ''')
        .eq('cliente', clienteId)
        .gt('total_importe', 0)
        .order('fecha', ascending: true);

    // Filtrar solo los que tienen saldo pendiente y son débitos (facturas)
    return (response as List).where((comp) {
      final totalImporte = (comp['total_importe'] as num).toDouble();
      final cancelado = (comp['cancelado'] as num?)?.toDouble() ?? 0;
      final saldo = totalImporte - cancelado;
      final tipoComprobante = comp['tipo_comprobante'] as int?;
      final tipoData = tipoComprobante != null ? tiposMap[tipoComprobante] : null;
      final multiplicador = tipoData?['multiplicador'] ?? 1;
      // Solo mostrar facturas pendientes (multiplicador 1 = débito del cliente)
      return saldo > 0.01 && multiplicador == 1;
    }).map((comp) {
      // Agregar datos del tipo de comprobante al resultado
      final tipoComprobante = comp['tipo_comprobante'] as int?;
      final tipoData = tipoComprobante != null ? tiposMap[tipoComprobante] : null;
      return {
        ...comp as Map<String, dynamic>,
        'tip_vent_mod_header': tipoData,
      };
    }).toList();
  }

  /// Genera un nuevo recibo de cobranza para cliente
  ///
  /// Crea un registro en ven_cli_header con tipo recibo
  /// y actualiza el campo cancelado de las transacciones pagadas
  Future<Map<String, dynamic>> generarRecibo({
    required int clienteId,
    required Map<int, double> transaccionesAPagar,
    required Map<int, double> formasPago,
    int? operadorId,
  }) async {
    // Validar que los totales coincidan
    final totalAPagar = transaccionesAPagar.values.fold(0.0, (a, b) => a + b);
    final totalFormasPago = formasPago.values.fold(0.0, (a, b) => a + b);

    if ((totalAPagar - totalFormasPago).abs() > 0.01) {
      throw Exception(
        'Los totales no coinciden: Total a pagar: \$${totalAPagar.toStringAsFixed(2)}, '
        'Total formas de pago: \$${totalFormasPago.toStringAsFixed(2)}'
      );
    }

    // Obtener próximo número de recibo
    // Buscar el máximo número de comprobante para tipo recibo (código 6 típicamente)
    // TODO: Verificar el código correcto de tipo recibo en tip_vent_mod_header
    const tipoReciboCliente = 6; // Tipo recibo de cliente - ajustar según datos

    final maxCompResult = await _supabase
        .from('ven_cli_header')
        .select('comprobante')
        .eq('tipo_comprobante', tipoReciboCliente)
        .order('comprobante', ascending: false)
        .limit(1);

    int nuevoNumeroRecibo = 1;
    if ((maxCompResult as List).isNotEmpty) {
      nuevoNumeroRecibo = (maxCompResult.first['comprobante'] as int) + 1;
    }

    final now = DateTime.now();
    final anioMes = now.year * 100 + now.month;

    // Crear el recibo en ven_cli_header
    final reciboData = {
      'comprobante': nuevoNumeroRecibo,
      'anio_mes': anioMes,
      'fecha': now.toIso8601String().split('T')[0],
      'cliente': clienteId,
      'tipo_comprobante': tipoReciboCliente,
      'nro_comprobante': nuevoNumeroRecibo.toString().padLeft(8, '0'),
      'total_importe': totalAPagar,
      'cancelado': 0,
      'fecha_real': now.toIso8601String().split('T')[0],
    };

    final insertResult = await _supabase
        .from('ven_cli_header')
        .insert(reciboData)
        .select('id_transaccion')
        .single();

    final reciboId = insertResult['id_transaccion'] as int;

    // Actualizar el campo cancelado de cada transacción pagada
    for (final entry in transaccionesAPagar.entries) {
      final idTransaccion = entry.key;
      final montoPagado = entry.value;

      // Obtener el cancelado actual
      final transaccion = await _supabase
          .from('ven_cli_header')
          .select('cancelado')
          .eq('id_transaccion', idTransaccion)
          .single();

      final canceladoActual = (transaccion['cancelado'] as num?)?.toDouble() ?? 0;
      final nuevoCancelado = canceladoActual + montoPagado;

      // Actualizar
      await _supabase
          .from('ven_cli_header')
          .update({'cancelado': nuevoCancelado})
          .eq('id_transaccion', idTransaccion);
    }

    // Crear items del recibo (uno por cada forma de pago)
    int itemNum = 1;
    for (final entry in formasPago.entries) {
      final conceptoId = entry.key;
      final monto = entry.value;

      // Obtener cuenta contable del concepto de tesorería
      final concepto = await _supabase
          .from('conceptos_tesoreria')
          .select('imputacion_contable, descripcion')
          .eq('id', conceptoId)
          .single();

      final cuentaContable = int.tryParse(concepto['imputacion_contable']?.toString() ?? '0') ?? 0;

      await _supabase.from('ven_cli_items').insert({
        'id_transaccion': reciboId,
        'comprobante': nuevoNumeroRecibo,
        'anio_mes': anioMes,
        'item': itemNum,
        'concepto': 'EXE',  // Exento por defecto
        'cuenta': cuentaContable,
        'importe': monto,
        'base_contable': monto,
        'alicuota': 0,
        'detalle': concepto['descripcion'],
      });

      itemNum++;
    }

    // Registrar en valores_tesoreria si existe la tabla
    try {
      for (final entry in formasPago.entries) {
        final conceptoId = entry.key;
        final monto = entry.value;

        await _supabase.from('valores_tesoreria').insert({
          'id_concepto': conceptoId,
          'fecha': now.toIso8601String().split('T')[0],
          'importe': monto,
          'numero_interno': nuevoNumeroRecibo,
          'tipo_entidad': 'CLI',  // Cliente
          'id_entidad': clienteId,
        });
      }
    } catch (e) {
      // Si falla valores_tesoreria, continuar (puede no existir)
      print('Advertencia: No se pudo registrar en valores_tesoreria: $e');
    }

    return {
      'numero_recibo': nuevoNumeroRecibo,
      'id_transaccion': reciboId,
      'total': totalAPagar,
    };
  }

  /// Obtiene el saldo total de un cliente
  Future<Map<String, double>> getSaldoCliente(int clienteId) async {
    // Primero obtener los tipos de comprobante
    final tiposResponse = await _supabase
        .from('tip_vent_mod_header')
        .select('codigo, multiplicador');

    final tiposMap = <int, int>{};
    for (final tipo in tiposResponse as List) {
      tiposMap[tipo['codigo'] as int] = tipo['multiplicador'] as int? ?? 1;
    }

    // Luego obtener los comprobantes (sin join)
    final response = await _supabase
        .from('ven_cli_header')
        .select('total_importe, cancelado, tipo_comprobante')
        .eq('cliente', clienteId);

    double totalDebitos = 0;
    double totalCreditos = 0;
    int totalTransacciones = 0;

    for (final comp in response) {
      final totalImporte = (comp['total_importe'] as num).toDouble();
      final cancelado = (comp['cancelado'] as num?)?.toDouble() ?? 0;
      final saldo = totalImporte - cancelado;
      final tipoComprobante = comp['tipo_comprobante'] as int?;
      final multiplicador = tipoComprobante != null ? (tiposMap[tipoComprobante] ?? 1) : 1;

      if (multiplicador == 1) {
        totalDebitos += saldo;
      } else {
        totalCreditos += saldo;
      }
      totalTransacciones++;
    }

    return {
      'total_debitos': totalDebitos,
      'total_creditos': totalCreditos,
      'saldo_total': totalDebitos - totalCreditos,  // Positivo = nos deben
      'total_transacciones': totalTransacciones.toDouble(),
    };
  }
}
