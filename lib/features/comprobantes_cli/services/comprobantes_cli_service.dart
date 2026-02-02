import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comprobante_cli_model.dart';
import '../../asientos/services/asientos_service.dart';
import '../../parametros/models/parametro_contable_model.dart';

class ComprobantesCliService {
  final SupabaseClient _supabase;
  late final AsientosService _asientosService;

  ComprobantesCliService(this._supabase) {
    _asientosService = AsientosService(_supabase);
  }

  /// Buscar comprobantes de clientes con filtros
  Future<List<VenCliHeader>> buscarComprobantes({
    int? cliente,
    int? tipoComprobante,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    String? nroComprobante,
    bool soloConSaldo = false,
    int limit = 100,
  }) async {
    var query = _supabase
        .from('ven_cli_header')
        .select('*, clientes(razon_social)');

    if (cliente != null) {
      query = query.eq('cliente', cliente);
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
        (response as List).map((json) => VenCliHeader.fromJson(json)).toList();

    if (soloConSaldo) {
      comprobantes = comprobantes.where((c) => c.saldo > 0).toList();
    }

    return comprobantes;
  }

  /// Obtener comprobante por ID con sus items
  Future<VenCliHeader?> getComprobante(int idTransaccion) async {
    final response = await _supabase
        .from('ven_cli_header')
        .select('*, clientes(razon_social), ven_cli_items(*)')
        .eq('id_transaccion', idTransaccion)
        .maybeSingle();

    if (response == null) return null;
    return VenCliHeader.fromJson(response);
  }

  /// Obtener comprobantes de un cliente específico
  Future<List<VenCliHeader>> getComprobantesPorCliente(
    int clienteId, {
    bool soloConSaldo = false,
    int limit = 100,
  }) async {
    final response = await _supabase
        .from('ven_cli_header')
        .select('*, clientes(razon_social)')
        .eq('cliente', clienteId)
        .order('fecha', ascending: false)
        .order('comprobante', ascending: false)
        .limit(limit);

    var comprobantes =
        (response as List).map((json) => VenCliHeader.fromJson(json)).toList();

    if (soloConSaldo) {
      comprobantes = comprobantes.where((c) => c.saldo > 0).toList();
    }

    return comprobantes;
  }

  /// Crear un nuevo comprobante con sus items
  Future<VenCliHeader> crearComprobante(
    VenCliHeader header,
    List<VenCliItem> items,
  ) async {
    // Obtener el próximo número de comprobante
    final maxCompResponse = await _supabase
        .from('ven_cli_header')
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

    final headerResponse = await _supabase
        .from('ven_cli_header')
        .insert(headerData)
        .select()
        .single();

    final nuevoHeader = VenCliHeader.fromJson(headerResponse);

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

      await _supabase.from('ven_cli_items').insert(itemsData);
    }

    // Generar asiento contable de ventas (solo para facturas)
    await _generarAsientoVenta(
      header: nuevoHeader,
      items: items,
    );

    return nuevoHeader;
  }

  /// Actualizar un comprobante existente y sus items
  Future<VenCliHeader> actualizarComprobante(
    VenCliHeader header,
    List<VenCliItem> items,
  ) async {
    if (header.idTransaccion == null) {
      throw Exception('El comprobante no tiene ID');
    }

    // Actualizar header
    await _supabase
        .from('ven_cli_header')
        .update(header.toJson())
        .eq('id_transaccion', header.idTransaccion!);

    // Eliminar items existentes
    await _supabase
        .from('ven_cli_items')
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

      await _supabase.from('ven_cli_items').insert(itemsData);
    }

    return (await getComprobante(header.idTransaccion!))!;
  }

  /// Eliminar un comprobante (y sus items por cascade)
  Future<void> eliminarComprobante(int idTransaccion) async {
    await _supabase
        .from('ven_cli_header')
        .delete()
        .eq('id_transaccion', idTransaccion);
  }

  /// Obtener tipos de comprobante de ventas
  Future<List<TipoComprobanteVenta>> getTiposComprobante() async {
    final response = await _supabase
        .from('tip_vent_mod_header')
        .select()
        .order('codigo');

    return (response as List)
        .map((json) => TipoComprobanteVenta.fromJson(json))
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
        .from('ven_cli_header')
        .update({'cancelado': nuevoCancelado})
        .eq('id_transaccion', idTransaccion);
  }

  /// Obtener resumen de cuenta corriente de un cliente
  Future<Map<String, dynamic>> getResumenCuentaCliente(int clienteId) async {
    final comprobantes = await getComprobantesPorCliente(clienteId);

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

  /// Genera el asiento contable para una factura de venta
  ///
  /// Asiento tipo Ventas (4):
  /// - DEBE: Cuenta Clientes (desde parámetros)
  /// - HABER: Cuenta(s) contable de cada item (desde ven_cli_items.cuenta)
  Future<void> _generarAsientoVenta({
    required VenCliHeader header,
    required List<VenCliItem> items,
  }) async {
    try {
      // Verificar que el tipo de comprobante genera asiento (multiplicador = 1 = factura)
      final tipoResponse = await _supabase
          .from('tip_vent_mod_header')
          .select('multiplicador')
          .eq('codigo', header.tipoComprobante)
          .maybeSingle();

      final multiplicador = tipoResponse?['multiplicador'] as int? ?? 1;

      // Solo generar asiento para facturas (multiplicador = 1)
      // Los recibos y NC tienen su propia lógica de asiento
      if (multiplicador != 1) {
        return;
      }

      // Obtener cuenta de clientes desde parámetros
      final paramResponse = await _supabase
          .from('parametros_contables')
          .select('valor')
          .eq('clave', ParametroContable.cuentaClientes)
          .maybeSingle();

      if (paramResponse == null || paramResponse['valor'] == null) {
        print('Advertencia: No se encontró cuenta de clientes en parámetros');
        return;
      }

      final cuentaClientes = int.tryParse(paramResponse['valor'].toString());
      if (cuentaClientes == null) {
        print('Advertencia: Cuenta de clientes inválida');
        return;
      }

      // Obtener nombre del cliente
      final clienteResponse = await _supabase
          .from('clientes')
          .select('razon_social')
          .eq('id', header.cliente)
          .maybeSingle();

      final nombreCliente = clienteResponse?['razon_social'] ?? 'Cliente ${header.cliente}';

      // Construir items del asiento
      final asientoItems = <AsientoItemData>[];

      // DEBE: Cuenta de Clientes por el total
      asientoItems.add(AsientoItemData(
        cuentaId: cuentaClientes,
        debe: header.totalImporte,
        haber: 0,
      ));

      // HABER: Una entrada por cada item con su cuenta contable
      for (final item in items) {
        if (item.cuenta == 0) {
          print('Advertencia: Item sin cuenta contable, omitiendo');
          continue;
        }

        asientoItems.add(AsientoItemData(
          cuentaId: item.cuenta,
          debe: 0,
          haber: item.importe,
        ));
      }

      // Si solo tenemos el DEBE (sin items válidos en HABER), no generar asiento
      if (asientoItems.length <= 1) {
        print('Advertencia: No hay items con cuenta contable válida');
        return;
      }

      // Crear el asiento
      await _asientosService.crearAsiento(
        tipoAsiento: AsientosService.tipoVentas,
        fecha: header.fecha,
        detalle: 'FC ${header.nroComprobante}',
        items: asientoItems,
        numeroComprobante: header.comprobante,
        nombrePersona: nombreCliente,
      );
    } catch (e) {
      // Si falla el asiento, registrar pero no abortar la operación
      print('Advertencia: No se pudo generar asiento contable: $e');
    }
  }
}
