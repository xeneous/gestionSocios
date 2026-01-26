class ParametroContable {
  final int? id;
  final String clave;
  final String? valor;
  final String? descripcion;
  final String tipo;

  ParametroContable({
    this.id,
    required this.clave,
    this.valor,
    this.descripcion,
    this.tipo = 'texto',
  });

  factory ParametroContable.fromJson(Map<String, dynamic> json) {
    return ParametroContable(
      id: json['id'] as int?,
      clave: json['clave'] as String,
      valor: json['valor'] as String?,
      descripcion: json['descripcion'] as String?,
      tipo: json['tipo'] as String? ?? 'texto',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'clave': clave,
      'valor': valor,
      'descripcion': descripcion,
      'tipo': tipo,
    };
  }

  ParametroContable copyWith({
    int? id,
    String? clave,
    String? valor,
    String? descripcion,
    String? tipo,
  }) {
    return ParametroContable(
      id: id ?? this.id,
      clave: clave ?? this.clave,
      valor: valor ?? this.valor,
      descripcion: descripcion ?? this.descripcion,
      tipo: tipo ?? this.tipo,
    );
  }

  // Claves predefinidas
  static const String cuentaProveedores = 'CUENTA_PROVEEDORES';
  static const String cuentaClientes = 'CUENTA_CLIENTES';
  static const String cuentaSponsors = 'CUENTA_SPONSORS';
}
