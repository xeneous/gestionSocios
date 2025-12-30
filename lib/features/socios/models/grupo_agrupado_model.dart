class GrupoAgrupado {
  final int id;
  final String codigo;
  final String descripcion;
  final bool activo;

  GrupoAgrupado({
    required this.id,
    required this.codigo,
    required this.descripcion,
    this.activo = true,
  });

  factory GrupoAgrupado.fromJson(Map<String, dynamic> json) {
    return GrupoAgrupado(
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      descripcion: json['descripcion'] as String,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'descripcion': descripcion,
      'activo': activo,
    };
  }
}
