class TipoComprobanteSocio {
  final String comprobante;  // PK
  final String descripcion;
  final int? idTipoMovimiento;
  final double? signo;  // 1 = débito, -1 = crédito
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Para UI - cargar descripción de tipo_movimiento
  String? tipoMovimientoDescripcion;

  TipoComprobanteSocio({
    required this.comprobante,
    required this.descripcion,
    this.idTipoMovimiento,
    this.signo,
    this.createdAt,
    this.updatedAt,
    this.tipoMovimientoDescripcion,
  });

  bool get esDebito => signo != null && signo! > 0;
  bool get esCredito => signo != null && signo! < 0;

  factory TipoComprobanteSocio.fromJson(Map<String, dynamic> json) {
    return TipoComprobanteSocio(
      comprobante: json['comprobante'] as String,
      descripcion: json['descripcion'] as String,
      idTipoMovimiento: json['id_tipo_movimiento'] as int?,
      signo: json['signo'] != null
          ? (json['signo'] as num).toDouble()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      tipoMovimientoDescripcion: json['tipo_movimiento_descripcion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comprobante': comprobante,
      'descripcion': descripcion,
      if (idTipoMovimiento != null) 'id_tipo_movimiento': idTipoMovimiento,
      if (signo != null) 'signo': signo,
    };
  }

  TipoComprobanteSocio copyWith({
    String? comprobante,
    String? descripcion,
    int? idTipoMovimiento,
    double? signo,
    String? tipoMovimientoDescripcion,
  }) {
    return TipoComprobanteSocio(
      comprobante: comprobante ?? this.comprobante,
      descripcion: descripcion ?? this.descripcion,
      idTipoMovimiento: idTipoMovimiento ?? this.idTipoMovimiento,
      signo: signo ?? this.signo,
      tipoMovimientoDescripcion: tipoMovimientoDescripcion ?? this.tipoMovimientoDescripcion,
    );
  }

  @override
  String toString() => '$comprobante - $descripcion';
}
