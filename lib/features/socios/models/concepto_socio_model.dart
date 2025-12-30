class ConceptoSocio {
  final int? id;
  final int socioId;
  final String concepto;  // FK a conceptos(concepto)
  final DateTime? fechaAlta;
  final DateTime? fechaVigencia;
  final double? importe;
  final DateTime? fechaBaja;

  ConceptoSocio({
    this.id,
    required this.socioId,
    required this.concepto,
    this.fechaAlta,
    this.fechaVigencia,
    this.importe,
    this.fechaBaja,
  });

  bool get activo => fechaBaja == null;

  factory ConceptoSocio.fromJson(Map<String, dynamic> json) => ConceptoSocio(
        id: json['id'],
        socioId: json['socio_id'],
        concepto: json['concepto'],
        fechaAlta: json['fecha_alta'] != null
            ? DateTime.parse(json['fecha_alta'])
            : null,
        fechaVigencia: json['fecha_vigencia'] != null
            ? DateTime.parse(json['fecha_vigencia'])
            : null,
        importe: json['importe']?.toDouble(),
        fechaBaja: json['fecha_baja'] != null
            ? DateTime.parse(json['fecha_baja'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'socio_id': socioId,
        'concepto': concepto,
        'fecha_alta': fechaAlta?.toIso8601String(),
        'fecha_vigencia': fechaVigencia?.toIso8601String(),
        'importe': importe,
        'fecha_baja': fechaBaja?.toIso8601String(),
      };

  ConceptoSocio copyWith({
    int? id,
    int? socioId,
    String? concepto,
    DateTime? fechaAlta,
    DateTime? fechaVigencia,
    double? importe,
    DateTime? fechaBaja,
  }) {
    return ConceptoSocio(
      id: id ?? this.id,
      socioId: socioId ?? this.socioId,
      concepto: concepto ?? this.concepto,
      fechaAlta: fechaAlta ?? this.fechaAlta,
      fechaVigencia: fechaVigencia ?? this.fechaVigencia,
      importe: importe ?? this.importe,
      fechaBaja: fechaBaja ?? this.fechaBaja,
    );
  }
}
