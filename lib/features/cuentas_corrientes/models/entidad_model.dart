class Entidad {
  final int id;
  final String descripcion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Entidad({
    required this.id,
    required this.descripcion,
    this.createdAt,
    this.updatedAt,
  });

  factory Entidad.fromJson(Map<String, dynamic> json) {
    return Entidad(
      id: json['id'] as int,
      descripcion: json['descripcion'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descripcion': descripcion,
    };
  }

  @override
  String toString() => '$id - $descripcion';
}
