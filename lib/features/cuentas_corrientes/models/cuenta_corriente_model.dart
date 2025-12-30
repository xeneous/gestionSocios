class CuentaCorriente {
  final int? idtransaccion;  // Autoincremental en BD
  final int socioId;
  final int entidadId;
  final DateTime fecha;
  final String tipoComprobante;
  final String? puntoVenta;
  final String? documentoNumero;
  final DateTime? fechaRendicion;
  final String? rendicion;
  final double? importe;
  final double? cancelado;
  final DateTime? vencimiento;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  // Para UI - información relacionada
  String? socioNombre;
  String? entidadDescripcion;
  String? tipoComprobanteDescripcion;
  int? signo;  // 1 para débito, -1 para crédito (desde tipos_comprobante_socios)

  CuentaCorriente({
    this.idtransaccion,
    required this.socioId,
    required this.entidadId,
    required this.fecha,
    required this.tipoComprobante,
    this.puntoVenta,
    this.documentoNumero,
    this.fechaRendicion,
    this.rendicion,
    this.importe,
    this.cancelado = 0.0,
    this.vencimiento,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.socioNombre,
    this.entidadDescripcion,
    this.tipoComprobanteDescripcion,
    this.signo,
  });

  // Computed properties
  double get saldoPendiente => (importe ?? 0.0) - (cancelado ?? 0.0);
  bool get estaCancelado => saldoPendiente.abs() < 0.01;
  bool get estaVencido => vencimiento != null && vencimiento!.isBefore(DateTime.now());

  factory CuentaCorriente.fromJson(Map<String, dynamic> json) {
    return CuentaCorriente(
      idtransaccion: json['idtransaccion'] as int?,
      socioId: json['socio_id'] as int,
      entidadId: json['entidad_id'] as int,
      fecha: DateTime.parse(json['fecha']),
      tipoComprobante: json['tipo_comprobante'] as String,
      puntoVenta: json['punto_venta'] as String?,
      documentoNumero: json['documento_numero'] as String?,
      fechaRendicion: json['fecha_rendicion'] != null
          ? DateTime.parse(json['fecha_rendicion'])
          : null,
      rendicion: json['rendicion'] as String?,
      importe: json['importe'] != null
          ? (json['importe'] as num).toDouble()
          : null,
      cancelado: json['cancelado'] != null
          ? (json['cancelado'] as num).toDouble()
          : 0.0,
      vencimiento: json['vencimiento'] != null
          ? DateTime.parse(json['vencimiento'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      socioNombre: json['socio_nombre'] as String?,
      entidadDescripcion: json['entidad_descripcion'] as String?,
      tipoComprobanteDescripcion: json['tipo_comprobante_descripcion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idtransaccion != null) 'idtransaccion': idtransaccion,
      'socio_id': socioId,
      'entidad_id': entidadId,
      'fecha': fecha.toIso8601String().split('T')[0],
      'tipo_comprobante': tipoComprobante,
      if (puntoVenta != null) 'punto_venta': puntoVenta,
      if (documentoNumero != null) 'documento_numero': documentoNumero,
      if (fechaRendicion != null) 'fecha_rendicion': fechaRendicion!.toIso8601String().split('T')[0],
      if (rendicion != null) 'rendicion': rendicion,
      if (importe != null) 'importe': importe,
      if (cancelado != null) 'cancelado': cancelado,
      if (vencimiento != null) 'vencimiento': vencimiento!.toIso8601String().split('T')[0],
    };
  }

  CuentaCorriente copyWith({
    int? idtransaccion,
    int? socioId,
    int? entidadId,
    DateTime? fecha,
    String? tipoComprobante,
    String? puntoVenta,
    String? documentoNumero,
    DateTime? fechaRendicion,
    String? rendicion,
    double? importe,
    double? cancelado,
    DateTime? vencimiento,
    String? socioNombre,
    String? entidadDescripcion,
    String? tipoComprobanteDescripcion,
    int? signo,
  }) {
    return CuentaCorriente(
      idtransaccion: idtransaccion ?? this.idtransaccion,
      socioId: socioId ?? this.socioId,
      entidadId: entidadId ?? this.entidadId,
      fecha: fecha ?? this.fecha,
      tipoComprobante: tipoComprobante ?? this.tipoComprobante,
      puntoVenta: puntoVenta ?? this.puntoVenta,
      documentoNumero: documentoNumero ?? this.documentoNumero,
      fechaRendicion: fechaRendicion ?? this.fechaRendicion,
      rendicion: rendicion ?? this.rendicion,
      importe: importe ?? this.importe,
      cancelado: cancelado ?? this.cancelado,
      vencimiento: vencimiento ?? this.vencimiento,
      socioNombre: socioNombre ?? this.socioNombre,
      entidadDescripcion: entidadDescripcion ?? this.entidadDescripcion,
      tipoComprobanteDescripcion: tipoComprobanteDescripcion ?? this.tipoComprobanteDescripcion,
      signo: signo ?? this.signo,
    );
  }
}
