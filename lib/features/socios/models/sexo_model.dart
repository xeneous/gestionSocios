class Sexo {
  final int id;
  final String descripcion;

  Sexo({
    required this.id,
    required this.descripcion,
  });

  factory Sexo.fromJson(Map<String, dynamic> json) {
    return Sexo(
      id: json['id'] as int,
      descripcion: json['descripcion'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descripcion': descripcion,
    };
  }
}
