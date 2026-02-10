class CategoriaResidente {
  final String codigo;
  final String descripcion;
  final double porcentajeDescuento;

  CategoriaResidente({
    required this.codigo,
    required this.descripcion,
    required this.porcentajeDescuento,
  });

  factory CategoriaResidente.fromJson(Map<String, dynamic> json) {
    return CategoriaResidente(
      codigo: json['codigo'] as String,
      descripcion: json['descripcion'] as String,
      porcentajeDescuento: (json['porcentaje_descuento'] as num).toDouble(),
    );
  }

  /// Factor para aplicar al valor (0.0 si 100% descuento, 1.0 si 0% descuento)
  double get factorValor => (100 - porcentajeDescuento) / 100;

  /// True si no paga cuota social (100% descuento)
  bool get noPagaCuota => porcentajeDescuento >= 100;

  @override
  String toString() => '$codigo - $descripcion';
}
