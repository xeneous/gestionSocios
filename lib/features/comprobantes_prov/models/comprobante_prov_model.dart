/// Item de comprobante de proveedor
class CompProvItem {
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
  final DateTime? fechaCierre;
  final String? factura;

  CompProvItem({
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
    this.fechaCierre,
    this.factura,
  });

  factory CompProvItem.fromJson(Map<String, dynamic> json) {
    return CompProvItem(
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
      fechaCierre: json['fecha_cierre'] != null
          ? DateTime.parse(json['fecha_cierre'] as String)
          : null,
      factura: json['factura'] as String?,
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
      if (fechaCierre != null) 'fecha_cierre': fechaCierre!.toIso8601String(),
      if (factura != null) 'factura': factura,
    };
  }

  CompProvItem copyWith({
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
    DateTime? fechaCierre,
    String? factura,
  }) {
    return CompProvItem(
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
      fechaCierre: fechaCierre ?? this.fechaCierre,
      factura: factura ?? this.factura,
    );
  }
}

/// Header de comprobante de proveedor
class CompProvHeader {
  final int? idTransaccion;
  final int comprobante;
  final int anioMes;
  final DateTime fecha;
  final int proveedor;
  final int tipoComprobante;
  final String nroComprobante;
  final String? tipoFactura;
  final double totalImporte;
  final double cancelado;
  final DateTime? fecha1Venc;
  final DateTime? fecha2Venc;
  final String estado;
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
  final List<CompProvItem>? items;
  final String? proveedorNombre;

  CompProvHeader({
    this.idTransaccion,
    required this.comprobante,
    required this.anioMes,
    required this.fecha,
    required this.proveedor,
    required this.tipoComprobante,
    required this.nroComprobante,
    this.tipoFactura,
    required this.totalImporte,
    this.cancelado = 0,
    this.fecha1Venc,
    this.fecha2Venc,
    required this.estado,
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
    this.proveedorNombre,
  });

  factory CompProvHeader.fromJson(Map<String, dynamic> json) {
    // Parsear items si vienen incluidos
    List<CompProvItem>? items;
    if (json['comp_prov_items'] != null) {
      items = (json['comp_prov_items'] as List)
          .map((item) => CompProvItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Obtener nombre del proveedor si viene incluido
    String? proveedorNombre;
    if (json['proveedores'] != null) {
      final prov = json['proveedores'] as Map<String, dynamic>;
      proveedorNombre = prov['razon_social'] as String?;
    }

    return CompProvHeader(
      idTransaccion: json['id_transaccion'] as int?,
      comprobante: json['comprobante'] as int,
      anioMes: json['anio_mes'] as int,
      fecha: DateTime.parse(json['fecha'] as String),
      proveedor: json['proveedor'] as int,
      tipoComprobante: json['tipo_comprobante'] as int,
      nroComprobante: (json['nro_comprobante'] as String).trim(),
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
      estado: (json['estado'] as String).trim(),
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
      proveedorNombre: proveedorNombre,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idTransaccion != null) 'id_transaccion': idTransaccion,
      'comprobante': comprobante,
      'anio_mes': anioMes,
      'fecha': fecha.toIso8601String(),
      'proveedor': proveedor,
      'tipo_comprobante': tipoComprobante,
      'nro_comprobante': nroComprobante,
      if (tipoFactura != null) 'tipo_factura': tipoFactura,
      'total_importe': totalImporte,
      'cancelado': cancelado,
      if (fecha1Venc != null) 'fecha1_venc': fecha1Venc!.toIso8601String(),
      if (fecha2Venc != null) 'fecha2_venc': fecha2Venc!.toIso8601String(),
      'estado': 'P',  // FORZADO: Siempre P
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

  CompProvHeader copyWith({
    int? idTransaccion,
    int? comprobante,
    int? anioMes,
    DateTime? fecha,
    int? proveedor,
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
    List<CompProvItem>? items,
    String? proveedorNombre,
  }) {
    return CompProvHeader(
      idTransaccion: idTransaccion ?? this.idTransaccion,
      comprobante: comprobante ?? this.comprobante,
      anioMes: anioMes ?? this.anioMes,
      fecha: fecha ?? this.fecha,
      proveedor: proveedor ?? this.proveedor,
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
      proveedorNombre: proveedorNombre ?? this.proveedorNombre,
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

/// Tipo de comprobante de compras
class TipoComprobanteCompra {
  final int codigo;
  final String comprobante;
  final String descripcion;
  final int? signo;
  final int? multiplicador;
  final String? sicore;
  final int? tipoStock;
  final int? cMov;
  final String? comp;
  final String? ivaCompras;
  final int? ie;
  final String? br;
  final int? modulo;

  TipoComprobanteCompra({
    required this.codigo,
    required this.comprobante,
    required this.descripcion,
    this.signo,
    this.multiplicador,
    this.sicore,
    this.tipoStock,
    this.cMov,
    this.comp,
    this.ivaCompras,
    this.ie,
    this.br,
    this.modulo,
  });

  factory TipoComprobanteCompra.fromJson(Map<String, dynamic> json) {
    return TipoComprobanteCompra(
      codigo: json['codigo'] as int,
      comprobante: (json['comprobante'] as String).trim(),
      descripcion: (json['descripcion'] as String).trim(),
      signo: json['signo'] as int?,
      multiplicador: json['multiplicador'] as int?,
      sicore: json['sicore'] as String?,
      tipoStock: json['tipo_stock'] as int?,
      cMov: json['c_mov'] as int?,
      comp: json['comp'] as String?,
      ivaCompras: json['iva_compras'] as String?,
      ie: json['ie'] as int?,
      br: json['br'] as String?,
      modulo: json['modulo'] as int?,
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
      if (cMov != null) 'c_mov': cMov,
      if (comp != null) 'comp': comp,
      if (ivaCompras != null) 'iva_compras': ivaCompras,
      if (ie != null) 'ie': ie,
      if (br != null) 'br': br,
      if (modulo != null) 'modulo': modulo,
    };
  }
}
