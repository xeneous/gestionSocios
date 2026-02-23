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

    // Generar asiento contable de ventas
    // Si falla, el comprobante ya fue guardado; propagamos con prefijo especial
    // para que la UI lo distinga y muestre advertencia en lugar de error fatal.
    try {
      await _generarAsientoVenta(
        header: nuevoHeader,
        items: items,
      );
    } catch (e) {
      throw Exception('ASIENTO_WARNING:$e');
    }

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

  /// Genera el asiento contable para un comprobante de ventas/sponsors.
  ///
  /// Usa el campo [signo] de [tip_vent_mod_header] para determinar sentido:
  ///   signo == 1 (Factura):   DEBE = CUENTA_SPONSORS (activo sube),  HABER = items (ingresos)
  ///   signo == 2 (NC):        DEBE = items (ingresos bajan),          HABER = CUENTA_SPONSORS
  ///   signo == 0 o null:      No genera asiento
  Future<void> _generarAsientoVenta({
    required VenCliHeader header,
    required List<VenCliItem> items,
  }) async {
    // Obtener signo y descripcion del tipo de comprobante
    final tipoResponse = await _supabase
        .from('tip_vent_mod_header')
        .select('signo, descripcion')
        .eq('codigo', header.tipoComprobante)
        .maybeSingle();

    final signo = tipoResponse?['signo'] as int?;
    final tipoDescripcion =
        (tipoResponse?['descripcion'] as String? ?? '').trim();

    // Solo genera asiento si signo es 1 o 2
    if (signo == null || signo == 0) return;

    // Obtener cuenta de sponsors desde parámetros
    final paramResponse = await _supabase
        .from('parametros_contables')
        .select('valor')
        .eq('clave', ParametroContable.cuentaSponsors)
        .maybeSingle();

    if (paramResponse == null || paramResponse['valor'] == null) {
      throw Exception(
          'No se encontró CUENTA_SPONSORS en parámetros_contables');
    }

    final cuentaSponsors = int.tryParse(paramResponse['valor'].toString());
    if (cuentaSponsors == null) {
      throw Exception(
          'El valor de CUENTA_SPONSORS no es un número válido: ${paramResponse['valor']}');
    }

    // Obtener nombre del cliente
    final clienteResponse = await _supabase
        .from('clientes')
        .select('razon_social')
        .eq('codigo', header.cliente)
        .maybeSingle();

    final nombreCliente =
        (clienteResponse?['razon_social'] as String?)?.trim() ??
            'Cliente ${header.cliente}';

    // Filtrar items con cuenta contable válida
    final itemsValidos = items.where((i) => i.cuenta != 0).toList();

    if (itemsValidos.isEmpty) {
      throw Exception(
          'No hay items con cuenta contable asignada; no se puede generar el asiento');
    }

    final totalItems =
        itemsValidos.fold(0.0, (sum, i) => sum + i.importe.abs());

    final asientoItems = <AsientoItemData>[];

    if (signo == 1) {
      // Factura: DEBE = sponsors (activo sube), HABER = items (ingresos)
      asientoItems.add(AsientoItemData(
        cuentaId: cuentaSponsors,
        debe: totalItems,
        haber: 0,
      ));
      for (final item in itemsValidos) {
        asientoItems.add(AsientoItemData(
          cuentaId: item.cuenta,
          debe: 0,
          haber: item.importe.abs(),
        ));
      }
    } else {
      // Signo 2 — NC: DEBE = items (ingresos bajan), HABER = sponsors (activo baja)
      for (final item in itemsValidos) {
        asientoItems.add(AsientoItemData(
          cuentaId: item.cuenta,
          debe: item.importe.abs(),
          haber: 0,
        ));
      }
      asientoItems.add(AsientoItemData(
        cuentaId: cuentaSponsors,
        debe: 0,
        haber: totalItems,
      ));
    }

    final nroComp = header.nroComprobante?.trim() ?? '';
    final detalle = nroComp.isNotEmpty
        ? '$tipoDescripcion $nroComp - $nombreCliente'
        : '$tipoDescripcion - $nombreCliente';

    await _asientosService.crearAsiento(
      tipoAsiento: AsientosService.tipoVentas,
      fecha: header.fecha,
      detalle: detalle,
      items: asientoItems,
      numeroComprobante: header.comprobante,
      nombrePersona: nombreCliente,
    );
  }
}
