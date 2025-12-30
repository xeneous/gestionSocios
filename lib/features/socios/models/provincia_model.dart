class Provincia {
  final int id;
  final String nombre;

  Provincia({
    required this.id,
    required this.nombre,
  });

  factory Provincia.fromJson(Map<String, dynamic> json) {
    return Provincia(
      id: json['id'] as int,  // Usar 'id' autoincremental de Supabase
      nombre: (json['descripcion'] as String).trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descripcion': nombre,
    };
  }
}
