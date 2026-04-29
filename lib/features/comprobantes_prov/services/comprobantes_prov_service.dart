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

  /// Buscar comprobantes de proveedores con filtros y paginación
  Future<List<CompProvHeader>> buscarComprobantes({
    int? proveedor,
    int? tipoComprobante,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    String? nroComprobante,
    bool soloConSaldo = false,
    bool sinPaginado = false,
    int page = 1,
    int pageSize = 100,
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
      query = query.gte('fecha', fechaDesde.toIso8601String().substring(0, 10));
    }

    if (fechaHasta != null) {
      query = query.lte('fecha', fechaHasta.toIso8601String().substring(0, 10));
    }

    if (nroComprobante != null && nroComprobante.isNotEmpty) {
      query = query.ilike('nro_comprobante', '%$nroComprobante%');
    }

    final orderedQuery = query
        .order('fecha', ascending: false)
        .order('comprobante', ascending: false);

    // Cuando soloConSaldo está activo, el filtro es client-side (saldo = total - cancelado
    // no es una columna real). Traemos todos los registros sin paginar y filtramos.
    // Cuando NO está activo, usamos paginación normal.
    final List response;
    if (soloConSaldo || sinPaginado) {
      response = await orderedQuery;
    } else {
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      response = await orderedQuery.range(from, to);
    }

    var comprobantes =
        (response).map((json) => CompProvHeader.fromJson(json)).toList();

    if (soloConSaldo) {
      comprobantes = comprobantes.where((c) => c.saldo > 0).toList();
    }

    return comprobantes;
  }

  /// Calcula el saldo acumulado de todos los movimientos ANTES de una fecha
  Future<double> getSaldoAnteriorProveedor(
    int proveedorId,
    DateTime fechaDesde,
  ) async {
    // Obtener multiplicadores de tipos
    final tiposResponse = await _supabase
        .from('tip_comp_mod_header')
        .select('codigo, multiplicador');

    final multiplicadores = <int, int>{};
    for (final t in tiposResponse as List) {
      if (t['multiplicador'] != null) {
        multiplicadores[t['codigo'] as int] = t['multiplicador'] as int;
      }
    }

    // Todos los comprobantes ANTES de fechaDesde (sin limit)
    final response = await _supabase
        .from('comp_prov_header')
        .select('tipo_comprobante, total_importe')
        .eq('proveedor', proveedorId)
        .lt('fecha', fechaDesde.toIso8601String().substring(0, 10));

    double saldo = 0;
    for (final row in response as List) {
      final mult = multiplicadores[row['tipo_comprobante'] as int] ?? 1;
      final importe = (row['total_importe'] as num).toDouble();
      // mult == 1 → factura (Haber, aumenta deuda)
      // mult == -1 → pago/NC (Debe, reduce deuda)
      saldo += mult == 1 ? importe : -importe;
    }
    return saldo;
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
    int page = 1,
    int pageSize = 100,
  }) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    final response = await _supabase
        .from('comp_prov_header')
        .select('*, proveedores(razon_social)')
        .eq('proveedor', proveedorId)
        .order('fecha', ascending: false)
        .order('comprobante', ascending: false)
        .range(from, to);

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

    // FORZAR estado si viene null o vacío
    if (headerData['estado'] == null || headerData['estado'].toString().isEmpty) {
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

    // Generar asiento contable de compras
    // Si falla, el comprobante ya fue guardado correctamente; propagamos el error
    // con un prefijo especial para que la UI lo distinga y muestre advertencia.
    try {
      await _generarAsientoCompra(
        header: nuevoHeader,
        items: items,
      );
    } catch (e) {
      throw Exception('ASIENTO_WARNING:$e');
    }

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

  /// Elimina un comprobante (factura/NC) de forma segura.
  /// Lanza excepción si tiene Órdenes de Pago aplicadas — deben eliminarse primero.
  /// El asiento contable queda huérfano ya que no hay FK directa al asiento.
  Future<void> eliminarFactura(int idTransaccion) async {
    // Verificar si hay OPs aplicadas a esta factura
    final notas = await _supabase
        .from('notas_imputacion')
        .select('id_operacion')
        .eq('id_transaccion', idTransaccion);

    if ((notas as List).isNotEmpty) {
      final ops = notas.map((n) => 'OP #${n['id_operacion']}').join(', ');
      throw Exception(
          'La factura tiene pagos aplicados ($ops). Elimine primero esas Órdenes de Pago.');
    }

    await _supabase
        .from('comp_prov_items')
        .delete()
        .eq('id_transaccion', idTransaccion);
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

  /// Genera el asiento contable para un comprobante de compra.
  ///
  /// Usa el campo [signo] de [tip_comp_mod_header] para determinar sentido:
  ///   signo == 2 (Factura):       DEBE = items,        HABER = CUENTA_PROVEEDORES
  ///   signo == 1 (NC/reversal):   DEBE = CUENTA_PROVEEDORES, HABER = items
  ///   signo == 0 o null:          No genera asiento
  Future<void> _generarAsientoCompra({
    required CompProvHeader header,
    required List<CompProvItem> items,
  }) async {
    // Obtener signo y descripcion del tipo de comprobante
    final tipoResponse = await _supabase
        .from('tip_comp_mod_header')
        .select('signo, descripcion')
        .eq('codigo', header.tipoComprobante)
        .maybeSingle();

    final signo = tipoResponse?['signo'] as int?;
    final tipoDescripcion =
        (tipoResponse?['descripcion'] as String? ?? '').trim();

    // Solo genera asiento si signo es 1 o 2
    if (signo == null || signo == 0) return;

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

    final cuentaProveedores =
        int.tryParse(paramResponse['valor'].toString());
    if (cuentaProveedores == null) {
      throw Exception(
          'El valor de CUENTA_PROVEEDORES no es un número válido: ${paramResponse['valor']}');
    }

    // Obtener nombre del proveedor
    final proveedorResponse = await _supabase
        .from('proveedores')
        .select('razon_social')
        .eq('codigo', header.proveedor)
        .maybeSingle();

    final nombreProveedor =
        (proveedorResponse?['razon_social'] as String?)?.trim() ??
            'Proveedor ${header.proveedor}';

    // Filtrar items con cuenta contable válida
    final itemsValidos = items.where((i) => i.cuenta != 0).toList();

    if (itemsValidos.isEmpty) {
      throw Exception(
          'No hay items con cuenta contable asignada; no se puede generar el asiento');
    }

    final totalItems =
        itemsValidos.fold(0.0, (sum, i) => sum + i.importe.abs());

    final asientoItems = <AsientoItemData>[];

    if (signo == 2) {
      // Factura: DEBE = items (gastos/activos), HABER = proveedores (pasivo sube)
      for (final item in itemsValidos) {
        asientoItems.add(AsientoItemData(
          cuentaId: item.cuenta,
          debe: item.importe.abs(),
          haber: 0,
        ));
      }
      asientoItems.add(AsientoItemData(
        cuentaId: cuentaProveedores,
        debe: 0,
        haber: totalItems,
      ));
    } else {
      // Signo 1 — NC/reversal: DEBE = proveedores (pasivo baja), HABER = items
      asientoItems.add(AsientoItemData(
        cuentaId: cuentaProveedores,
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
    }

    final detalle =
        '$tipoDescripcion ${header.nroComprobante.trim()} - $nombreProveedor';

    await _asientosService.crearAsiento(
      tipoAsiento: AsientosService.tipoCompras,
      fecha: header.fecha,
      detalle: detalle,
      items: asientoItems,
      numeroComprobante: header.comprobante,
      nombrePersona: nombreProveedor,
    );
  }
}
