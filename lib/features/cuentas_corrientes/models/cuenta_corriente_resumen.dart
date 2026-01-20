class CuentaCorrienteResumen {
  final int socioId;
  final String apellido;
  final String nombre;
  final String? grupo;
  final double saldo;
  final double rdaPendiente;
  final int mesesImpagos; // Cantidad de registros con cancelado < importe
  final String? telefono;
  final String? email;
  final int? tarjetaId;
  final bool residente;

  CuentaCorrienteResumen({
    required this.socioId,
    required this.apellido,
    required this.nombre,
    this.grupo,
    required this.saldo,
    required this.rdaPendiente,
    this.mesesImpagos = 0,
    this.telefono,
    this.email,
    this.tarjetaId,
    this.residente = false,
  });

  bool get tieneEmail => email != null && email!.isNotEmpty;
  bool get tieneSaldoPendiente => saldo > 0;
}
