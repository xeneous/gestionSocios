class DetalleCuentaCorriente {
  final int idtransaccion;
  final int item;
  final String concepto;  // FK a conceptos(concepto)
  final double cantidad;
  final double importe;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  // Para UI - información relacionada
  String? conceptoDescripcion;
  String? modalidad;
  String? grupo;

  DetalleCuentaCorriente({
    required this.idtransaccion,
    required this.item,
    required this.concepto,
    this.cantidad = 1.0,
    required this.importe,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.conceptoDescripcion,
    this.modalidad,
    this.grupo,
  });

  // Computed property
  double get importeTotal => cantidad * importe;

  factory DetalleCuentaCorriente.fromJson(Map<String, dynamic> json) {
    return DetalleCuentaCorriente(
      idtransaccion: json['idtransaccion'] as int,
      item: json['item'] as int,
      concepto: json['concepto'] as String,
      cantidad: json['cantidad'] != null
          ? (json['cantidad'] as num).toDouble()
          : 1.0,
      importe: (json['importe'] as num).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      conceptoDescripcion: json['concepto_descripcion'] as String?,
      modalidad: json['modalidad'] as String?,
      grupo: json['grupo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idtransaccion': idtransaccion,
      'item': item,
      'concepto': concepto,
      'cantidad': cantidad,
      'importe': importe,
    };
  }

  DetalleCuentaCorriente copyWith({
    int? idtransaccion,
    int? item,
    String? concepto,
    double? cantidad,
    double? importe,
    String? conceptoDescripcion,
    String? modalidad,
    String? grupo,
  }) {
    return DetalleCuentaCorriente(
      idtransaccion: idtransaccion ?? this.idtransaccion,
      item: item ?? this.item,
      concepto: concepto ?? this.concepto,
      cantidad: cantidad ?? this.cantidad,
      importe: importe ?? this.importe,
      conceptoDescripcion: conceptoDescripcion ?? this.conceptoDescripcion,
      modalidad: modalidad ?? this.modalidad,
      grupo: grupo ?? this.grupo,
    );
  }
}
