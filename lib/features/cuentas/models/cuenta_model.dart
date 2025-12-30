class Cuenta {
  final int cuenta;  // Primary key - número de cuenta
  final int? corta;
  final String descripcion;
  final String? descripcionResumida;
  final String? sigla;
  final int? tipoCuentaContable;
  final bool imputable;
  final int? rubro;
  final int? subrubro;
  final bool activo;

  Cuenta({
    required this.cuenta,
    this.corta,
    required this.descripcion,
    this.descripcionResumida,
    this.sigla,
    this.tipoCuentaContable,
    this.imputable = false,
    this.rubro,
    this.subrubro,
    this.activo = true,
  });

  factory Cuenta.fromJson(Map<String, dynamic> json) => Cuenta(
        cuenta: json['cuenta'],
        corta: json['corta'],
        descripcion: json['descripcion'],
        descripcionResumida: json['descripcion_resumida'],
        sigla: json['sigla'],
        tipoCuentaContable: json['tipo_cuenta_contable'],
        imputable: json['imputable'] ?? false,
        rubro: json['rubro'],
        subrubro: json['subrubro'],
        activo: json['activo'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'cuenta': cuenta,
        'corta': corta,
        'descripcion': descripcion,
        'descripcion_resumida': descripcionResumida,
        'sigla': sigla,
        'tipo_cuenta_contable': tipoCuentaContable,
        'imputable': imputable,
        'rubro': rubro,
        'subrubro': subrubro,
        'activo': activo,
      };

  Cuenta copyWith({
    int? cuenta,
    int? corta,
    String? descripcion,
    String? descripcionResumida,
    String? sigla,
    int? tipoCuentaContable,
    bool? imputable,
    int? rubro,
    int? subrubro,
    bool? activo,
  }) {
    return Cuenta(
      cuenta: cuenta ?? this.cuenta,
      corta: corta ?? this.corta,
      descripcion: descripcion ?? this.descripcion,
      descripcionResumida: descripcionResumida ?? this.descripcionResumida,
      sigla: sigla ?? this.sigla,
      tipoCuentaContable: tipoCuentaContable ?? this.tipoCuentaContable,
      imputable: imputable ?? this.imputable,
      rubro: rubro ?? this.rubro,
      subrubro: subrubro ?? this.subrubro,
      activo: activo ?? this.activo,
    );
  }
}
