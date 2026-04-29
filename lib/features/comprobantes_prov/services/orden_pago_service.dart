import 'package:supabase_flutter/supabase_flutter.dart';
import '../../asientos/services/asientos_service.dart';
import '../../parametros/models/parametro_contable_model.dart';

/// Servicio para manejar operaciones de orden de pago a proveedores
class OrdenPagoService {
  final SupabaseClient _supabase;
  late final AsientosService _asientosService;

  OrdenPagoService(this._supabase) {
    _asientosService = AsientosService(_supabase);
  }

  /// Obtiene los comprobantes pendientes de pago de un proveedor
  Future<List<Map<String, dynamic>>> getComprobantesPendientes(
      int proveedorId) async {
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
      final tipoData =
          tipoComprobante != null ? tiposMap[tipoComprobante] : null;
      final multiplicador = tipoData?['multiplicador'] ?? 1;
      // Solo mostrar facturas pendientes (multiplicador 1 = crédito del proveedor, debemos pagarle)
      return saldo > 0.01 && multiplicador == 1;
    }).map((comp) {
      // Agregar datos del tipo de comprobante al resultado
      final tipoComprobante = comp['tipo_comprobante'] as int?;
      final tipoData =
          tipoComprobante != null ? tiposMap[tipoComprobante] : null;
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
    DateTime? fecha,
    int? operadorId,
  }) async {
    // Validar que los totales coincidan
    final totalAPagar = transaccionesAPagar.values.fold(0.0, (a, b) => a + b);
    final totalFormasPago = formasPago.values.fold(0.0, (a, b) => a + b);

    if ((totalAPagar - totalFormasPago).abs() > 0.01) {
      throw Exception(
          'Los totales no coinciden: Total a pagar: \$${totalAPagar.toStringAsFixed(2)}, '
          'Total formas de pago: \$${totalFormasPago.toStringAsFixed(2)}');
    }

    // Obtener próximo número de orden de pago
    // Tipo 0 = OP (Orden de Pago) según tip_comp_mod_header
    const tipoOrdenPago = 0;

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

    final fechaOP = fecha ?? DateTime.now();
    final anioMes = fechaOP.year * 100 + fechaOP.month;

    // Crear la orden de pago en comp_prov_header
    final ordenPagoData = {
      'comprobante': nuevoNumeroOP,
      'anio_mes': anioMes,
      'fecha': fechaOP.toIso8601String().split('T')[0],
      'proveedor': proveedorId,
      'tipo_comprobante': tipoOrdenPago,
      'nro_comprobante': nuevoNumeroOP.toString().padLeft(8, '0'),
      'total_importe': totalAPagar,
      'cancelado': 0,
      'estado': 'C', // Cancelado (la OP se genera como pagada)
      'fecha_real': fechaOP.toIso8601String().split('T')[0],
    };

    final insertResult = await _supabase
        .from('comp_prov_header')
        .insert(ordenPagoData)
        .select('id_transaccion')
        .single();

    final ordenPagoId = insertResult['id_transaccion'] as int;

    // Actualizar el campo cancelado de cada transacción pagada y registrar trazabilidad
    for (final entry in transaccionesAPagar.entries) {
      final idTransaccion = entry.key;
      final montoPagado = entry.value;

      // Obtener el cancelado actual
      final transaccion = await _supabase
          .from('comp_prov_header')
          .select('cancelado')
          .eq('id_transaccion', idTransaccion)
          .single();

      final canceladoActual =
          (transaccion['cancelado'] as num?)?.toDouble() ?? 0;
      final nuevoCancelado = canceladoActual + montoPagado;

      // Actualizar campo cancelado
      await _supabase.from('comp_prov_header').update(
          {'cancelado': nuevoCancelado}).eq('id_transaccion', idTransaccion);

      // Registrar trazabilidad en notas_imputacion
      await _supabase.from('notas_imputacion').insert({
        'id_operacion': ordenPagoId,
        'id_transaccion': idTransaccion,
        'importe': montoPagado,
        'tipo_operacion': 1, // 1 = Orden de Pago (proveedores)
        'observacion': 'OP $nuevoNumeroOP',
      });
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

      final cuentaContable =
          int.tryParse(concepto['imputacion_contable']?.toString() ?? '0') ?? 0;

      await _supabase.from('comp_prov_items').insert({
        'id_transaccion': ordenPagoId,
        'comprobante': nuevoNumeroOP,
        'anio_mes': anioMes,
        'item': itemNum,
        'concepto': 'EXE', // Exento por defecto
        'cuenta': cuentaContable,
        'importe': monto,
        'base_contable': monto,
        'alicuota': 0,
        'detalle': concepto['descripcion'],
      });

      itemNum++;
    }

    // Registrar en valores_tesoreria y operaciones_contables
    final idsValoresTesoreria = <int>[];
    for (final entry in formasPago.entries) {
      final conceptoId = entry.key;
      final monto = entry.value;

      final valorResult = await _supabase
          .from('valores_tesoreria')
          .insert({
            'idtransaccion_origen': ordenPagoId,
            'idconcepto_tesoreria': conceptoId,
            'fecha_emision': fechaOP.toIso8601String().split('T')[0],
            'importe': -monto, // Negativo porque es egreso
            'numero_interno': nuevoNumeroOP,
            'tipo_movimiento': 2, // 2 = Egreso (pago a proveedor)
          })
          .select('id')
          .single();

      idsValoresTesoreria.add(valorResult['id'] as int);
    }

    // Crear registro en operaciones_contables
    final opResult = await _supabase
        .from('operaciones_contables')
        .insert({
          'tipo_operacion': 'ORDEN_PAGO',
          'numero_comprobante': nuevoNumeroOP,
          'fecha': fechaOP.toIso8601String().split('T')[0],
          'entidad_tipo': 'PROVEEDOR',
          'entidad_id': proveedorId,
          'total': totalAPagar,
        })
        .select('id')
        .single();
    final operacionId = opResult['id'] as int;

    // Vincular valores_tesoreria con la operación
    for (final valorId in idsValoresTesoreria) {
      await _supabase.from('operaciones_detalle_valores_tesoreria').insert({
        'operacion_id': operacionId,
        'valor_tesoreria_id': valorId,
      });
    }

    // Generar asiento contable de egreso
    // Si falla, la OP ya está guardada; se retorna el error sin abortar.
    int? numeroAsiento;
    String? asientoError;
    try {
      numeroAsiento = await _generarAsientoOrdenPago(
        proveedorId: proveedorId,
        formasPago: formasPago,
        totalAPagar: totalAPagar,
        numeroOrdenPago: nuevoNumeroOP,
        fecha: fechaOP,
      );

      // Actualizar operaciones_contables con el asiento generado
      final anioMes = fechaOP.year * 100 + fechaOP.month;
      await _supabase.from('operaciones_contables').update({
        'asiento_numero': numeroAsiento,
        'asiento_anio_mes': anioMes,
        'asiento_tipo': 2, // tipoEgreso
      }).eq('id', operacionId);
    } catch (e) {
      asientoError = e.toString().replaceFirst('Exception: ', '');
    }

    return {
      'numero_orden_pago': nuevoNumeroOP,
      'id_transaccion': ordenPagoId,
      'operacion_id': operacionId,
      'total': totalAPagar,
      'numero_asiento': numeroAsiento,
      'asiento_error': asientoError,
    };
  }

  /// Genera el asiento contable para una orden de pago.
  ///
  /// Asiento tipo Egreso (2):
  /// - DEBE: Cuenta Proveedores (desde parámetros_contables)
  /// - HABER: Cuenta(s) de cada forma de pago (desde conceptos_tesoreria)
  ///
  /// Retorna el número de asiento generado. Lanza excepción si falla.
  Future<int> _generarAsientoOrdenPago({
    required int proveedorId,
    required Map<int, double> formasPago,
    required double totalAPagar,
    required int numeroOrdenPago,
    required DateTime fecha,
  }) async {
    // Obtener cuenta de proveedores desde parámetros
    final paramResponse = await _supabase
        .from('parametros_contables')
        .select('valor')
        .eq('clave', ParametroContable.cuentaProveedores)
        .maybeSingle();

    if (paramResponse == null || paramResponse['valor'] == null) {
      throw Exception(
          'No se encontró CUENTA_PROVEEDORES en parámetros_contables');
    }

    final cuentaProveedores = int.tryParse(paramResponse['valor'].toString());
    if (cuentaProveedores == null) {
      throw Exception(
          'El valor de CUENTA_PROVEEDORES no es un número válido: ${paramResponse['valor']}');
    }

    // Obtener nombre del proveedor
    final proveedorResponse = await _supabase
        .from('proveedores')
        .select('razon_social')
        .eq('codigo', proveedorId)
        .maybeSingle();

    final nombreProveedor =
        (proveedorResponse?['razon_social'] as String?)?.trim() ??
            'Proveedor $proveedorId';

    // Construir items del asiento
    final items = <AsientoItemData>[];

    // DEBE: Cuenta Proveedores — baja el pasivo
    items.add(AsientoItemData(
      cuentaId: cuentaProveedores,
      debe: totalAPagar,
      haber: 0,
    ));

    // HABER: una línea por cada forma de pago
    for (final entry in formasPago.entries) {
      final conceptoId = entry.key;
      final monto = entry.value;

      final concepto = await _supabase
          .from('conceptos_tesoreria')
          .select('imputacion_contable, descripcion')
          .eq('id', conceptoId)
          .maybeSingle();

      final cuentaPago =
          int.tryParse(concepto?['imputacion_contable']?.toString() ?? '0');
      if (cuentaPago == null || cuentaPago == 0) {
        final desc = concepto?['descripcion'] ?? 'ID $conceptoId';
        throw Exception(
            'La forma de pago "$desc" no tiene cuenta contable configurada '
            '(imputacion_contable vacío en conceptos_tesoreria)');
      }

      items.add(AsientoItemData(
        cuentaId: cuentaPago,
        debe: 0,
        haber: monto,
      ));
    }

    return await _asientosService.crearAsiento(
      tipoAsiento: AsientosService.tipoEgreso,
      fecha: fecha,
      detalle: 'OP $numeroOrdenPago - $nombreProveedor',
      items: items,
      numeroComprobante: numeroOrdenPago,
    );
  }

  /// Elimina una Orden de Pago y revierte todos sus efectos:
  /// - Revierte cancelado en cada factura imputada
  /// - Elimina notas_imputacion
  /// - Elimina valores_tesoreria, operaciones_contables y su asiento contable
  /// - Elimina comp_prov_items y comp_prov_header
  ///
  /// Retorna lista de facturas revertidas para mostrar al usuario.
  Future<List<Map<String, dynamic>>> eliminarOrdenPago(int idTransaccion) async {
    // 1. Obtener la OP
    final opRow = await _supabase
        .from('comp_prov_header')
        .select('comprobante, anio_mes, fecha, total_importe')
        .eq('id_transaccion', idTransaccion)
        .single();

    final opComprobante = opRow['comprobante'] as int;

    // 2. Obtener notas_imputacion para saber qué facturas revertir
    final notas = await _supabase
        .from('notas_imputacion')
        .select('id_transaccion, importe')
        .eq('id_operacion', idTransaccion);

    final facturasRevertidas = <Map<String, dynamic>>[];

    // 3. Revertir cancelado en cada factura
    for (final nota in notas as List) {
      final idFactura = nota['id_transaccion'] as int;
      final importe = (nota['importe'] as num).toDouble();

      final facturaRow = await _supabase
          .from('comp_prov_header')
          .select('cancelado, nro_comprobante')
          .eq('id_transaccion', idFactura)
          .maybeSingle();

      if (facturaRow != null) {
        final canceladoActual = (facturaRow['cancelado'] as num?)?.toDouble() ?? 0;
        final nuevoCancelado = (canceladoActual - importe).clamp(0.0, double.infinity);
        await _supabase
            .from('comp_prov_header')
            .update({'cancelado': nuevoCancelado})
            .eq('id_transaccion', idFactura);
        facturasRevertidas.add({
          'nro_comprobante': facturaRow['nro_comprobante'],
          'importe': importe,
        });
      }
    }

    // 4. Eliminar notas_imputacion de esta OP
    await _supabase
        .from('notas_imputacion')
        .delete()
        .eq('id_operacion', idTransaccion);

    // 5. Buscar operaciones_contables para encontrar el asiento
    final opContable = await _supabase
        .from('operaciones_contables')
        .select('id, asiento_numero, asiento_anio_mes, asiento_tipo')
        .eq('numero_comprobante', opComprobante)
        .eq('tipo_operacion', 'ORDEN_PAGO')
        .maybeSingle();

    if (opContable != null) {
      final operacionId = opContable['id'] as int;
      final asientoNumero = opContable['asiento_numero'] as int?;
      final asientoAnioMes = opContable['asiento_anio_mes'] as int?;
      final asientoTipo = opContable['asiento_tipo'] as int?;

      // 5a. Eliminar operaciones_detalle_valores_tesoreria
      await _supabase
          .from('operaciones_detalle_valores_tesoreria')
          .delete()
          .eq('operacion_id', operacionId);

      // 5b. Eliminar asiento contable
      if (asientoNumero != null && asientoAnioMes != null && asientoTipo != null) {
        await _supabase
            .from('asientos_items')
            .delete()
            .eq('asiento', asientoNumero)
            .eq('anio_mes', asientoAnioMes)
            .eq('tipo_asiento', asientoTipo);
        await _supabase
            .from('asientos_header')
            .delete()
            .eq('asiento', asientoNumero)
            .eq('anio_mes', asientoAnioMes)
            .eq('tipo_asiento', asientoTipo);
      }

      // 5c. Eliminar operaciones_contables
      await _supabase
          .from('operaciones_contables')
          .delete()
          .eq('id', operacionId);
    }

    // 6. Eliminar valores_tesoreria
    await _supabase
        .from('valores_tesoreria')
        .delete()
        .eq('idtransaccion_origen', idTransaccion);

    // 7. Eliminar items y header
    await _supabase
        .from('comp_prov_items')
        .delete()
        .eq('id_transaccion', idTransaccion);
    await _supabase
        .from('comp_prov_header')
        .delete()
        .eq('id_transaccion', idTransaccion);

    return facturasRevertidas;
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

    double totalFacturas = 0; // Lo que debemos (facturas)
    double totalPagos = 0; // Lo que pagamos (OP, NC)
    int totalTransacciones = 0;

    for (final comp in response) {
      final totalImporte = (comp['total_importe'] as num).toDouble();
      final cancelado = (comp['cancelado'] as num?)?.toDouble() ?? 0;
      final saldo = totalImporte - cancelado;
      final tipoComprobante = comp['tipo_comprobante'] as int?;
      final multiplicador =
          tipoComprobante != null ? (tiposMap[tipoComprobante] ?? 1) : 1;

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
      'saldo_total': totalFacturas - totalPagos, // Positivo = debemos
      'total_transacciones': totalTransacciones.toDouble(),
    };
  }
}
