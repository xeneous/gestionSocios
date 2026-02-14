class LugarResidencia {
  final int id;
  final String nombre;
  final bool activo;

  LugarResidencia({
    required this.id,
    required this.nombre,
    this.activo = true,
  });

  factory LugarResidencia.fromJson(Map<String, dynamic> json) {
    return LugarResidencia(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      activo: json['activo'] as bool? ?? true,
    );
  }
}
