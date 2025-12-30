class TipoMovimiento {
  final int id;
  final String descripcion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TipoMovimiento({
    required this.id,
    required this.descripcion,
    this.createdAt,
    this.updatedAt,
  });

  factory TipoMovimiento.fromJson(Map<String, dynamic> json) {
    return TipoMovimiento(
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
  String toString() => descripcion;
}
