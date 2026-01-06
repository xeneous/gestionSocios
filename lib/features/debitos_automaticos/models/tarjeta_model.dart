class Tarjeta {
  final int id;
  final String nombre;
  final String? codigo;
  final bool activo;
  final DateTime createdAt;

  Tarjeta({
    required this.id,
    required this.nombre,
    this.codigo,
    required this.activo,
    required this.createdAt,
  });

  factory Tarjeta.fromJson(Map<String, dynamic> json) {
    return Tarjeta(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      codigo: json['codigo'] as String?,
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
