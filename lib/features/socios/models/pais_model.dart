class Pais {
  final int id;
  final String nombre;

  Pais({
    required this.id,
    required this.nombre,
  });

  factory Pais.fromJson(Map<String, dynamic> json) {
    return Pais(
      id: json['id'] as int,  // Supabase usa 'id'
      nombre: (json['nombre'] as String).trim(),  // Supabase usa 'nombre'
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}
