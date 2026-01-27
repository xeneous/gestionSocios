import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comprobante_prov_model.dart';
import '../../asientos/services/asientos_service.dart';
import '../../parametros/models/parametro_contable_model.dart';

class ComprobantesProvService {
  final SupabaseClient _supabase;
  late final AsientosService _asientosService;

  ComprobantesProvService(this._supabase) {
    _asientosService = AsientosService(_supabase);
  }

  /// Buscar comprobantes de proveedores con filtros
  Future<List<CompProvHeader>> buscarComprobantes({
    int? proveedor,
    int? tipoComprobante,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    String? nroComprobante,
    bool soloConSaldo = false,
    int limit = 100,
  }) async {
    var query = _supabase
        .from('comp_prov_header')
        .select('*, proveedores(razon_social)');

    if (proveedor != null) {
      query = query.eq('proveedor', proveedor);
    }

    if (tipoComprobante != null) {
      query = query.eq('tipo_comprobante', tipoComprobante);
    }

    if (fechaDesde != null) {
      query = query.gte('fecha', fechaDesde.toIso8601String());
    }

    if (fechaHasta != null) {
      query = query.lte('fecha', fechaHasta.toIso8601String());
    }

    if (nroComprobante != null && nroComprobante.isNotEmpty) {
      query = query.ilike('nro_comprobante', '%$nroComprobante%');
    }

    final response = await query
        .order('fecha', ascending: false)
        .order('comprobante', ascending: false)
        .limit(limit);

    var comprobantes =
        (response as List).map((json) => CompProvHeader.fromJson(json)).toList();

    if (soloConSaldo) {
      comprobantes = comprobantes.where((c) => c.saldo > 0).toList();
    }

    return comprobantes;
  }

  /// Obtener comprobante por ID con sus items
  Future<CompProvHeader?> getComprobante(int idTransaccion) async {
    final response = await _supabase
        .from('comp_prov_header')
        .select('*, proveedores(razon_social), comp_prov_items(*)')
        .eq('id_transaccion', idTransaccion)
        .maybeSingle();

    if (response == null) return null;
    return CompProvHeader.fromJson(response);
  }

  /// Obtener comprobantes de un proveedor específico
  Future<List<CompProvHeader>> getComprobantesPorProveedor(
    int proveedorId, {
    bool soloConSaldo = false,
    int limit = 100,
  }) async {
    final response = await _supabase
        .from('comp_prov_header')
        .select('*, proveedores(razon_social)')
        .eq('proveedor', proveedorId)
        .order('fecha', ascending: false)
        .order('comprobante', ascending: false)
        .limit(limit);

    var comprobantes =
        (response as List).map((json) => CompProvHeader.fromJson(json)).toList();

    if (soloConSaldo) {
      comprobantes = comprobantes.where((c) => c.saldo > 0).toList();
    }

    return comprobantes;
  }

  /// Crear un nuevo comprobante con sus items
  Future<CompProvHeader> crearComprobante(
    CompProvHeader header,
    List<CompProvItem> items,
  ) async {
    // Obtener el próximo número de comprobante
    final maxCompResponse = await _supabase
        .from('comp_prov_header')
        .select('comprobante')
        .eq('anio_mes', header.anioMes)
        .order('comprobante', ascending: false)
        .limit(1);

    int nuevoComprobante = 1;
    if ((maxCompResponse as List).isNotEmpty) {
      nuevoComprobante = (maxCompResponse[0]['comprobante'] as int) + 1;
    }

    // Insertar header
    final headerData = header.toJson();
    headerData['comprobante'] = nuevoComprobante;

    // DEBUG: Verificar estado
    print('🔍 DEBUG - Estado antes de insertar: ${headerData['estado']}');
    print('🔍 DEBUG - Header completo: $headerData');
    
    // FORZAR estado si viene null o vacío
    if (headerData['estado'] == null || headerData['estado'].toString().isEmpty) {
      print('⚠️ Estado era null/vacío, forzando a P');
      headerData['estado'] = 'P';
    }

    final headerResponse = await _supabase
        .from('comp_prov_header')
        .insert(headerData)
        .select()
        .single();

    final nuevoHeader = CompProvHeader.fromJson(headerResponse);

    // Insertar items
    if (items.isNotEmpty) {
      final itemsData = items.asMap().entries.map((entry) {
        final item = entry.value;
        final itemJson = item.toJson();
        itemJson['id_transaccion'] = nuevoHeader.idTransaccion;
        itemJson['comprobante'] = nuevoComprobante;
        itemJson['anio_mes'] = header.anioMes;
        itemJson['item'] = entry.key + 1;
        return itemJson;
      }).toList();

      await _supabase.from('comp_prov_items').insert(itemsData);
    }

    // Generar asiento contable de compras (solo para facturas, no para OP/NC)
    // El tipo de comprobante determina si genera asiento
    await _generarAsientoCompra(
      header: nuevoHeader,
      items: items,
    );

    return nuevoHeader;
  }

  /// Actualizar un comprobante existente y sus items
  Future<CompProvHeader> actualizarComprobante(
    CompProvHeader header,
    List<CompProvItem> items,
  ) async {
    if (header.idTransaccion == null) {
      throw Exception('El comprobante no tiene ID');
    }

    // Actualizar header
    await _supabase
        .from('comp_prov_header')
        .update(header.toJson())
        .eq('id_transaccion', header.idTransaccion!);

    // Eliminar items existentes
    await _supabase
        .from('comp_prov_items')
        .delete()
        .eq('id_transaccion', header.idTransaccion!);

    // Insertar nuevos items
    if (items.isNotEmpty) {
      final itemsData = items.asMap().entries.map((entry) {
        final item = entry.value;
        final itemJson = item.toJson();
        itemJson['id_transaccion'] = header.idTransaccion;
        itemJson['comprobante'] = header.comprobante;
        itemJson['anio_mes'] = header.anioMes;
        itemJson['item'] = entry.key + 1;
        itemJson.remove('id_campo'); // Remover para que genere nuevo ID
        return itemJson;
      }).toList();

      await _supabase.from('comp_prov_items').insert(itemsData);
    }

    return (await getComprobante(header.idTransaccion!))!;
  }

  /// Eliminar un comprobante (y sus items por cascade)
  Future<void> eliminarComprobante(int idTransaccion) async {
    await _supabase
        .from('comp_prov_header')
        .delete()
        .eq('id_transaccion', idTransaccion);
  }

  /// Obtener tipos de comprobante de compras
  Future<List<TipoComprobanteCompra>> getTiposComprobante() async {
    final response = await _supabase
        .from('tip_comp_mod_header')
        .select()
        .order('codigo');

    return (response as List)
        .map((json) => TipoComprobanteCompra.fromJson(json))
        .toList();
  }

  /// Registrar pago/cancelación parcial
  Future<void> registrarCancelacion(int idTransaccion, double monto) async {
    final comprobante = await getComprobante(idTransaccion);
    if (comprobante == null) {
      throw Exception('Comprobante no encontrado');
    }

    final nuevoCancelado = comprobante.cancelado + monto;
    if (nuevoCancelado > comprobante.totalImporte) {
      throw Exception('El monto de cancelación excede el saldo');
    }

    await _supabase
        .from('comp_prov_header')
        .update({'cancelado': nuevoCancelado})
        .eq('id_transaccion', idTransaccion);
  }

  /// Obtener resumen de cuenta corriente de un proveedor
  Future<Map<String, dynamic>> getResumenCuentaProveedor(int proveedorId) async {
    final comprobantes = await getComprobantesPorProveedor(proveedorId);

    double totalFacturado = 0;
    double totalCancelado = 0;
    int cantidadComprobantes = comprobantes.length;
    int comprobantesConSaldo = 0;

    for (final comp in comprobantes) {
      totalFacturado += comp.totalImporte;
      totalCancelado += comp.cancelado;
      if (comp.saldo > 0) {
        comprobantesConSaldo++;
      }
    }

    return {
      'totalFacturado': totalFacturado,
      'totalCancelado': totalCancelado,
      'saldoPendiente': totalFacturado - totalCancelado,
      'cantidadComprobantes': cantidadComprobantes,
      'comprobantesConSaldo': comprobantesConSaldo,
    };
  }

  /// Genera el asiento contable para una factura de compra
  ///
  /// Asiento tipo Compras (3):
  /// - DEBE: Cuenta(s) contable de cada item (desde comp_prov_items.cuenta)
  /// - HABER: Cuenta Proveedores (desde parámetros)
  Future<void> _generarAsientoCompra({
    required CompProvHeader header,
    required List<CompProvItem> items,
  }) async {
    try {
      // Verificar que el tipo de comprobante genera asiento (multiplicador = 1 = factura)
      final tipoResponse = await _supabase
          .from('tip_comp_mod_header')
          .select('multiplicador')
          .eq('codigo', header.tipoComprobante)
          .maybeSingle();

      final multiplicador = tipoResponse?['multiplicador'] as int? ?? 1;

      // Solo generar asiento para facturas (multiplicador = 1)
      // Las OP y NC tienen su propia lógica de asiento
      if (multiplicador != 1) {
        return;
      }

      // Obtener cuenta de proveedores desde parámetros
      final paramResponse = await _supabase
          .from('parametros_contables')
          .select('valor')
          .eq('clave', ParametroContable.cuentaProveedores)
          .maybeSingle();

      if (paramResponse == null || paramResponse['valor'] == null) {
        print('Advertencia: No se encontró cuenta de proveedores en parámetros');
        return;
      }

      final cuentaProveedores = int.tryParse(paramResponse['valor'].toString());
      if (cuentaProveedores == null) {
        print('Advertencia: Cuenta de proveedores inválida');
        return;
      }

      // Obtener nombre del proveedor
      final proveedorResponse = await _supabase
          .from('proveedores')
          .select('razon_social')
          .eq('id', header.proveedor)
          .maybeSingle();

      final nombreProveedor = proveedorResponse?['razon_social'] ?? 'Proveedor ${header.proveedor}';

      // Construir items del asiento
      final asientoItems = <AsientoItemData>[];

      // DEBE: Una entrada por cada item con su cuenta contable
      for (final item in items) {
        if (item.cuenta == 0) {
          print('Advertencia: Item sin cuenta contable, omitiendo');
          continue;
        }

        asientoItems.add(AsientoItemData(
          cuentaId: item.cuenta,
          debe: item.importe,
          haber: 0,
        ));
      }

      // Si no hay items válidos, no generar asiento
      if (asientoItems.isEmpty) {
        print('Advertencia: No hay items con cuenta contable válida');
        return;
      }

      // HABER: Cuenta de Proveedores por el total
      asientoItems.add(AsientoItemData(
        cuentaId: cuentaProveedores,
        debe: 0,
        haber: header.totalImporte,
      ));

      // Crear el asiento
      await _asientosService.crearAsiento(
        tipoAsiento: AsientosService.tipoCompras,
        fecha: header.fecha,
        detalle: 'FC ${header.nroComprobante}',
        items: asientoItems,
        numeroComprobante: header.comprobante,
        nombrePersona: nombreProveedor,
      );
    } catch (e) {
      // Si falla el asiento, registrar pero no abortar la operación
      print('Advertencia: No se pudo generar asiento contable: $e');
    }
  }
}
