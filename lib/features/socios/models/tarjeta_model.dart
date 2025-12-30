class Tarjeta {
  final int id;
  final String codigo;
  final String descripcion;

  Tarjeta({
    required this.id,
    required this.codigo,
    required this.descripcion,
  });

  factory Tarjeta.fromJson(Map<String, dynamic> json) {
    return Tarjeta(
      id: json['id'] as int,
      codigo: json['codigo'].toString(), // Convert to string (handles both int and String from DB)
      descripcion: json['descripcion'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'descripcion': descripcion,
    };
  }
}
