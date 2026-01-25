import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comprobante_cli_model.dart';

class ComprobantesCliService {
  final SupabaseClient _supabase;

  ComprobantesCliService(this._supabase);

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
}
