class ConceptoTesoreria {
  final int id;
  final String? descripcion;
  final String? imputacionContable;
  final int modalidad;
  final String ci; // S o N
  final String ce; // S o N
  final int? unificador;
  final int mostrador;
  final int monedaExtranjera;

  ConceptoTesoreria({
    required this.id,
    this.descripcion,
    this.imputacionContable,
    required this.modalidad,
    required this.ci,
    required this.ce,
    this.unificador,
    required this.mostrador,
    required this.monedaExtranjera,
  });

  factory ConceptoTesoreria.fromJson(Map<String, dynamic> json) {
    return ConceptoTesoreria(
      id: json['id'] as int,
      descripcion: json['descripcion'] as String?,
      imputacionContable: json['imputacion_contable'] as String?,
      modalidad: json['modalidad'] as int? ?? 0,
      ci: json['ci'] as String? ?? 'N',
      ce: json['ce'] as String? ?? 'N',
      unificador: json['unificador'] as int?,
      mostrador: json['mostrador'] as int? ?? 0,
      monedaExtranjera: json['moneda_extranjera'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descripcion': descripcion,
      'imputacion_contable': imputacionContable,
      'modalidad': modalidad,
      'ci': ci,
      'ce': ce,
      'unificador': unificador,
      'mostrador': mostrador,
      'moneda_extranjera': monedaExtranjera,
    };
  }

  /// Indica si es una forma de pago para cartera de ingreso (cobros)
  bool get esCarteraIngreso => ci == 'S';

  /// Indica si es una forma de pago para cartera de egreso (pagos)
  bool get esCarteraEgreso => ce == 'S';

  /// Indica si está disponible en mostrador
  bool get esDisponibleMostrador => mostrador == 1;

  /// Indica si acepta moneda extranjera
  bool get aceptaMonedaExtranjera => monedaExtranjera == 1;
}
