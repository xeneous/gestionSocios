/// Item de comprobante de cliente (ventas)
class VenCliItem {
  final int? idCampo;
  final int? idTransaccion;
  final int comprobante;
  final int anioMes;
  final int item;
  final String concepto;
  final int cuenta;
  final double importe;
  final double baseContable;
  final int? area;
  final String? detalle;
  final double alicuota;
  final String? grilla;
  final double? base;

  VenCliItem({
    this.idCampo,
    this.idTransaccion,
    required this.comprobante,
    required this.anioMes,
    required this.item,
    required this.concepto,
    required this.cuenta,
    required this.importe,
    required this.baseContable,
    this.area,
    this.detalle,
    required this.alicuota,
    this.grilla,
    this.base,
  });

  factory VenCliItem.fromJson(Map<String, dynamic> json) {
    return VenCliItem(
      idCampo: json['id_campo'] as int?,
      idTransaccion: json['id_transaccion'] as int?,
      comprobante: json['comprobante'] as int,
      anioMes: json['anio_mes'] as int,
      item: json['item'] as int,
      concepto: (json['concepto'] as String).trim(),
      cuenta: json['cuenta'] as int,
      importe: (json['importe'] as num).toDouble(),
      baseContable: (json['base_contable'] as num).toDouble(),
      area: json['area'] as int?,
      detalle: json['detalle'] as String?,
      alicuota: (json['alicuota'] as num).toDouble(),
      grilla: json['grilla'] as String?,
      base: json['base'] != null ? (json['base'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idCampo != null) 'id_campo': idCampo,
      if (idTransaccion != null) 'id_transaccion': idTransaccion,
      'comprobante': comprobante,
      'anio_mes': anioMes,
      'item': item,
      'concepto': concepto,
      'cuenta': cuenta,
      'importe': importe,
      'base_contable': baseContable,
      if (area != null) 'area': area,
      if (detalle != null) 'detalle': detalle,
      'alicuota': alicuota,
      if (grilla != null) 'grilla': grilla,
      if (base != null) 'base': base,
    };
  }

  VenCliItem copyWith({
    int? idCampo,
    int? idTransaccion,
    int? comprobante,
    int? anioMes,
    int? item,
    String? concepto,
    int? cuenta,
    double? importe,
    double? baseContable,
    int? area,
    String? detalle,
    double? alicuota,
    String? grilla,
    double? base,
  }) {
    return VenCliItem(
      idCampo: idCampo ?? this.idCampo,
      idTransaccion: idTransaccion ?? this.idTransaccion,
      comprobante: comprobante ?? this.comprobante,
      anioMes: anioMes ?? this.anioMes,
      item: item ?? this.item,
      concepto: concepto ?? this.concepto,
      cuenta: cuenta ?? this.cuenta,
      importe: importe ?? this.importe,
      baseContable: baseContable ?? this.baseContable,
      area: area ?? this.area,
      detalle: detalle ?? this.detalle,
      alicuota: alicuota ?? this.alicuota,
      grilla: grilla ?? this.grilla,
      base: base ?? this.base,
    );
  }
}

/// Header de comprobante de cliente (ventas)
class VenCliHeader {
  final int? idTransaccion;
  final int comprobante;
  final int anioMes;
  final DateTime fecha;
  final int cliente;
  final int tipoComprobante;
  final String? nroComprobante;
  final String? tipoFactura;
  final double totalImporte;
  final double cancelado;
  final DateTime? fecha1Venc;
  final DateTime? fecha2Venc;
  final String? estado;
  final DateTime fechaReal;
  final int? centroCosto;
  final String? descripcionImporte;
  final int? moneda;
  final double? importeOrigen;
  final double? tc;
  final double? docC;
  final double? canceladoOrigen;
  final DateTime? createdAt;

  // Relaciones
  final List<VenCliItem>? items;
  final String? clienteNombre;

  VenCliHeader({
    this.idTransaccion,
    required this.comprobante,
    required this.anioMes,
    required this.fecha,
    required this.cliente,
    required this.tipoComprobante,
    this.nroComprobante,
    this.tipoFactura,
    required this.totalImporte,
    this.cancelado = 0,
    this.fecha1Venc,
    this.fecha2Venc,
    this.estado,
    required this.fechaReal,
    this.centroCosto,
    this.descripcionImporte,
    this.moneda,
    this.importeOrigen,
    this.tc,
    this.docC,
    this.canceladoOrigen,
    this.createdAt,
    this.items,
    this.clienteNombre,
  });

  factory VenCliHeader.fromJson(Map<String, dynamic> json) {
    // Parsear items si vienen incluidos
    List<VenCliItem>? items;
    if (json['ven_cli_items'] != null) {
      items = (json['ven_cli_items'] as List)
          .map((item) => VenCliItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Obtener nombre del cliente si viene incluido
    String? clienteNombre;
    if (json['clientes'] != null) {
      final cli = json['clientes'] as Map<String, dynamic>;
      clienteNombre = cli['razon_social'] as String?;
    }

    return VenCliHeader(
      idTransaccion: json['id_transaccion'] as int?,
      comprobante: json['comprobante'] as int,
      anioMes: json['anio_mes'] as int,
      fecha: DateTime.parse(json['fecha'] as String),
      cliente: json['cliente'] as int,
      tipoComprobante: json['tipo_comprobante'] as int,
      nroComprobante: json['nro_comprobante'] != null
          ? (json['nro_comprobante'] as String).trim()
          : null,
      tipoFactura: json['tipo_factura'] as String?,
      totalImporte: (json['total_importe'] as num).toDouble(),
      cancelado: json['cancelado'] != null
          ? (json['cancelado'] as num).toDouble()
          : 0,
      fecha1Venc: json['fecha1_venc'] != null
          ? DateTime.parse(json['fecha1_venc'] as String)
          : null,
      fecha2Venc: json['fecha2_venc'] != null
          ? DateTime.parse(json['fecha2_venc'] as String)
          : null,
      estado: json['estado'] != null
          ? (json['estado'] as String).trim()
          : null,
      fechaReal: DateTime.parse(json['fecha_real'] as String),
      centroCosto: json['centro_costo'] as int?,
      descripcionImporte: json['descripcion_importe'] as String?,
      moneda: json['moneda'] as int?,
      importeOrigen: json['importe_origen'] != null
          ? (json['importe_origen'] as num).toDouble()
          : null,
      tc: json['tc'] != null ? (json['tc'] as num).toDouble() : null,
      docC: json['doc_c'] != null ? (json['doc_c'] as num).toDouble() : null,
      canceladoOrigen: json['cancelado_origen'] != null
          ? (json['cancelado_origen'] as num).toDouble()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      items: items,
      clienteNombre: clienteNombre,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idTransaccion != null) 'id_transaccion': idTransaccion,
      'comprobante': comprobante,
      'anio_mes': anioMes,
      'fecha': fecha.toIso8601String(),
      'cliente': cliente,
      'tipo_comprobante': tipoComprobante,
      if (nroComprobante != null) 'nro_comprobante': nroComprobante,
      if (tipoFactura != null) 'tipo_factura': tipoFactura,
      'total_importe': totalImporte,
      'cancelado': cancelado,
      if (fecha1Venc != null) 'fecha1_venc': fecha1Venc!.toIso8601String(),
      if (fecha2Venc != null) 'fecha2_venc': fecha2Venc!.toIso8601String(),
      'estado': estado ?? 'P',  // Siempre incluir estado, default 'P'
      'fecha_real': fechaReal.toIso8601String(),
      if (centroCosto != null) 'centro_costo': centroCosto,
      if (descripcionImporte != null) 'descripcion_importe': descripcionImporte,
      if (moneda != null) 'moneda': moneda,
      if (importeOrigen != null) 'importe_origen': importeOrigen,
      if (tc != null) 'tc': tc,
      if (docC != null) 'doc_c': docC,
      if (canceladoOrigen != null) 'cancelado_origen': canceladoOrigen,
    };
  }

  VenCliHeader copyWith({
    int? idTransaccion,
    int? comprobante,
    int? anioMes,
    DateTime? fecha,
    int? cliente,
    int? tipoComprobante,
    String? nroComprobante,
    String? tipoFactura,
    double? totalImporte,
    double? cancelado,
    DateTime? fecha1Venc,
    DateTime? fecha2Venc,
    String? estado,
    DateTime? fechaReal,
    int? centroCosto,
    String? descripcionImporte,
    int? moneda,
    double? importeOrigen,
    double? tc,
    double? docC,
    double? canceladoOrigen,
    DateTime? createdAt,
    List<VenCliItem>? items,
    String? clienteNombre,
  }) {
    return VenCliHeader(
      idTransaccion: idTransaccion ?? this.idTransaccion,
      comprobante: comprobante ?? this.comprobante,
      anioMes: anioMes ?? this.anioMes,
      fecha: fecha ?? this.fecha,
      cliente: cliente ?? this.cliente,
      tipoComprobante: tipoComprobante ?? this.tipoComprobante,
      nroComprobante: nroComprobante ?? this.nroComprobante,
      tipoFactura: tipoFactura ?? this.tipoFactura,
      totalImporte: totalImporte ?? this.totalImporte,
      cancelado: cancelado ?? this.cancelado,
      fecha1Venc: fecha1Venc ?? this.fecha1Venc,
      fecha2Venc: fecha2Venc ?? this.fecha2Venc,
      estado: estado ?? this.estado,
      fechaReal: fechaReal ?? this.fechaReal,
      centroCosto: centroCosto ?? this.centroCosto,
      descripcionImporte: descripcionImporte ?? this.descripcionImporte,
      moneda: moneda ?? this.moneda,
      importeOrigen: importeOrigen ?? this.importeOrigen,
      tc: tc ?? this.tc,
      docC: docC ?? this.docC,
      canceladoOrigen: canceladoOrigen ?? this.canceladoOrigen,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      clienteNombre: clienteNombre ?? this.clienteNombre,
    );
  }

  /// Saldo pendiente del comprobante
  double get saldo => totalImporte - cancelado;

  /// Si está totalmente cancelado
  bool get estaCancelado => saldo <= 0;

  /// Descripción del tipo de factura
  String get tipoFacturaDesc {
    switch (tipoFactura) {
      case 'A':
        return 'Factura A';
      case 'B':
        return 'Factura B';
      case 'C':
        return 'Factura C';
      case 'M':
        return 'Factura M';
      default:
        return tipoFactura ?? '';
    }
  }
}

/// Tipo de comprobante de ventas
class TipoComprobanteVenta {
  final int codigo;
  final String comprobante;
  final String descripcion;
  final int? signo;
  final int? multiplicador;
  final String? sicore;
  final int? tipoStock;
  final int? modulo;
  final String? ivaVentas;
  final int? cMov;
  final String? comp;
  final String? concCompra;
  final int? ie;
  final int? wsa;
  final int? wsb;
  final int? wse;
  final int? wsc;

  TipoComprobanteVenta({
    required this.codigo,
    required this.comprobante,
    required this.descripcion,
    this.signo,
    this.multiplicador,
    this.sicore,
    this.tipoStock,
    this.modulo,
    this.ivaVentas,
    this.cMov,
    this.comp,
    this.concCompra,
    this.ie,
    this.wsa,
    this.wsb,
    this.wse,
    this.wsc,
  });

  factory TipoComprobanteVenta.fromJson(Map<String, dynamic> json) {
    return TipoComprobanteVenta(
      codigo: json['codigo'] as int,
      comprobante: (json['comprobante'] as String).trim(),
      descripcion: (json['descripcion'] as String).trim(),
      signo: json['signo'] as int?,
      multiplicador: json['multiplicador'] as int?,
      sicore: json['sicore'] as String?,
      tipoStock: json['tipo_stock'] as int?,
      modulo: json['modulo'] as int?,
      ivaVentas: json['iva_ventas'] as String?,
      cMov: json['c_mov'] as int?,
      comp: json['comp'] as String?,
      concCompra: json['conc_compra'] as String?,
      ie: json['ie'] as int?,
      wsa: json['wsa'] as int?,
      wsb: json['wsb'] as int?,
      wse: json['wse'] as int?,
      wsc: json['wsc'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'comprobante': comprobante,
      'descripcion': descripcion,
      if (signo != null) 'signo': signo,
      if (multiplicador != null) 'multiplicador': multiplicador,
      if (sicore != null) 'sicore': sicore,
      if (tipoStock != null) 'tipo_stock': tipoStock,
      if (modulo != null) 'modulo': modulo,
      if (ivaVentas != null) 'iva_ventas': ivaVentas,
      if (cMov != null) 'c_mov': cMov,
      if (comp != null) 'comp': comp,
      if (concCompra != null) 'conc_compra': concCompra,
      if (ie != null) 'ie': ie,
      if (wsa != null) 'wsa': wsa,
      if (wsb != null) 'wsb': wsb,
      if (wse != null) 'wse': wse,
      if (wsc != null) 'wsc': wsc,
    };
  }
}
