class Concepto {
  final String concepto;  // This is the primary key
  final String descripcion;
  final int? entidad;
  final String? modalidad;
  final double? importe;
  final String? grupo;
  final bool? activo;

  Concepto({
    required this.concepto,
    required this.descripcion,
    this.entidad,
    this.modalidad,
    this.importe,
    this.grupo,
    this.activo,
  });

  factory Concepto.fromJson(Map<String, dynamic> json) {
    return Concepto(
      concepto: json['concepto'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      entidad: json['entidad'] as int?,
      modalidad: json['modalidad'] as String?,
      importe: json['importe'] != null ? (json['importe'] as num).toDouble() : null,
      grupo: json['grupo'] as String?,
      activo: json['activo'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'concepto': concepto,
        'descripcion': descripcion,
        'entidad': entidad,
        'modalidad': modalidad,
        'importe': importe,
        'grupo': grupo,
        'activo': activo,
      };

  @override
  String toString() => '$concepto - $descripcion';
}
