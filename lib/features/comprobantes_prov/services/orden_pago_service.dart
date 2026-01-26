import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para manejar operaciones de orden de pago a proveedores
class OrdenPagoService {
  final SupabaseClient _supabase;

  OrdenPagoService(this._supabase);

  /// Obtiene los comprobantes pendientes de pago de un proveedor
  Future<List<Map<String, dynamic>>> getComprobantesPendientes(int proveedorId) async {
    // Primero obtener los tipos de comprobante para saber el multiplicador
    final tiposResponse = await _supabase
        .from('tip_comp_mod_header')
        .select('codigo, comprobante, descripcion, multiplicador, signo');

    final tiposMap = <int, Map<String, dynamic>>{};
    for (final tipo in tiposResponse as List) {
      tiposMap[tipo['codigo'] as int] = tipo;
    }

    // Luego obtener los comprobantes (sin join)
    final response = await _supabase
        .from('comp_prov_header')
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
        .eq('proveedor', proveedorId)
        .gt('total_importe', 0)
        .order('fecha', ascending: true);

    // Filtrar solo los que tienen saldo pendiente y son créditos (facturas de proveedor)
    return (response as List).where((comp) {
      final totalImporte = (comp['total_importe'] as num).toDouble();
      final cancelado = (comp['cancelado'] as num?)?.toDouble() ?? 0;
      final saldo = totalImporte - cancelado;
      final tipoComprobante = comp['tipo_comprobante'] as int?;
      final tipoData = tipoComprobante != null ? tiposMap[tipoComprobante] : null;
      final multiplicador = tipoData?['multiplicador'] ?? 1;
      // Solo mostrar facturas pendientes (multiplicador 1 = crédito del proveedor, debemos pagarle)
      return saldo > 0.01 && multiplicador == 1;
    }).map((comp) {
      // Agregar datos del tipo de comprobante al resultado
      final tipoComprobante = comp['tipo_comprobante'] as int?;
      final tipoData = tipoComprobante != null ? tiposMap[tipoComprobante] : null;
      return {
        ...comp as Map<String, dynamic>,
        'tip_comp_mod_header': tipoData,
      };
    }).toList();
  }

  /// Genera una nueva orden de pago para proveedor
  ///
  /// Crea un registro en comp_prov_header con tipo orden de pago
  /// y actualiza el campo cancelado de las transacciones pagadas
  Future<Map<String, dynamic>> generarOrdenPago({
    required int proveedorId,
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

    // Obtener próximo número de orden de pago
    // TODO: Verificar el código correcto de tipo orden de pago en tip_comp_mod_header
    const tipoOrdenPago = 7; // Tipo orden de pago - ajustar según datos

    final maxCompResult = await _supabase
        .from('comp_prov_header')
        .select('comprobante')
        .eq('tipo_comprobante', tipoOrdenPago)
        .order('comprobante', ascending: false)
        .limit(1);

    int nuevoNumeroOP = 1;
    if ((maxCompResult as List).isNotEmpty) {
      nuevoNumeroOP = (maxCompResult.first['comprobante'] as int) + 1;
    }

    final now = DateTime.now();
    final anioMes = now.year * 100 + now.month;

    // Crear la orden de pago en comp_prov_header
    final ordenPagoData = {
      'comprobante': nuevoNumeroOP,
      'anio_mes': anioMes,
      'fecha': now.toIso8601String().split('T')[0],
      'proveedor': proveedorId,
      'tipo_comprobante': tipoOrdenPago,
      'nro_comprobante': nuevoNumeroOP.toString().padLeft(8, '0'),
      'total_importe': totalAPagar,
      'cancelado': 0,
      'fecha_real': now.toIso8601String().split('T')[0],
    };

    final insertResult = await _supabase
        .from('comp_prov_header')
        .insert(ordenPagoData)
        .select('id_transaccion')
        .single();

    final ordenPagoId = insertResult['id_transaccion'] as int;

    // Actualizar el campo cancelado de cada transacción pagada
    for (final entry in transaccionesAPagar.entries) {
      final idTransaccion = entry.key;
      final montoPagado = entry.value;

      // Obtener el cancelado actual
      final transaccion = await _supabase
          .from('comp_prov_header')
          .select('cancelado')
          .eq('id_transaccion', idTransaccion)
          .single();

      final canceladoActual = (transaccion['cancelado'] as num?)?.toDouble() ?? 0;
      final nuevoCancelado = canceladoActual + montoPagado;

      // Actualizar
      await _supabase
          .from('comp_prov_header')
          .update({'cancelado': nuevoCancelado})
          .eq('id_transaccion', idTransaccion);
    }

    // Crear items de la orden de pago (uno por cada forma de pago)
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

      await _supabase.from('comp_prov_items').insert({
        'id_transaccion': ordenPagoId,
        'comprobante': nuevoNumeroOP,
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

    // Registrar en valores_tesoreria como egreso
    try {
      for (final entry in formasPago.entries) {
        final conceptoId = entry.key;
        final monto = entry.value;

        await _supabase.from('valores_tesoreria').insert({
          'id_concepto': conceptoId,
          'fecha': now.toIso8601String().split('T')[0],
          'importe': -monto,  // Negativo porque es egreso
          'numero_interno': nuevoNumeroOP,
          'tipo_entidad': 'PRO',  // Proveedor
          'id_entidad': proveedorId,
        });
      }
    } catch (e) {
      // Si falla valores_tesoreria, continuar (puede no existir o tener otra estructura)
      // ignore: avoid_print
      print('Advertencia: No se pudo registrar en valores_tesoreria: $e');
    }

    return {
      'numero_orden_pago': nuevoNumeroOP,
      'id_transaccion': ordenPagoId,
      'total': totalAPagar,
    };
  }

  /// Obtiene el saldo total de un proveedor
  Future<Map<String, double>> getSaldoProveedor(int proveedorId) async {
    // Primero obtener los tipos de comprobante
    final tiposResponse = await _supabase
        .from('tip_comp_mod_header')
        .select('codigo, multiplicador');

    final tiposMap = <int, int>{};
    for (final tipo in tiposResponse as List) {
      tiposMap[tipo['codigo'] as int] = tipo['multiplicador'] as int? ?? 1;
    }

    // Luego obtener los comprobantes (sin join)
    final response = await _supabase
        .from('comp_prov_header')
        .select('total_importe, cancelado, tipo_comprobante')
        .eq('proveedor', proveedorId);

    double totalFacturas = 0;  // Lo que debemos (facturas)
    double totalPagos = 0;     // Lo que pagamos (OP, NC)
    int totalTransacciones = 0;

    for (final comp in response) {
      final totalImporte = (comp['total_importe'] as num).toDouble();
      final cancelado = (comp['cancelado'] as num?)?.toDouble() ?? 0;
      final saldo = totalImporte - cancelado;
      final tipoComprobante = comp['tipo_comprobante'] as int?;
      final multiplicador = tipoComprobante != null ? (tiposMap[tipoComprobante] ?? 1) : 1;

      if (multiplicador == 1) {
        // Facturas = aumenta deuda
        totalFacturas += saldo;
      } else {
        // Pagos/NC = disminuye deuda
        totalPagos += saldo;
      }
      totalTransacciones++;
    }

    return {
      'total_facturas': totalFacturas,
      'total_pagos': totalPagos,
      'saldo_total': totalFacturas - totalPagos,  // Positivo = debemos
      'total_transacciones': totalTransacciones.toDouble(),
    };
  }
}
