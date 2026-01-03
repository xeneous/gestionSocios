class ValorTesoreria {
  final int id;
  final int? idtransaccionOrigen;
  final int? tipoMovimiento;
  final int? idconceptoTesoreria;
  final DateTime? fechaEmision;
  final DateTime? vencimiento;
  final String? banco;
  final int? cuenta;
  final int? sucursal;
  final int? numero;
  final int? numeroInterno;
  final String? firma;
  final double importe;
  final double cancelado;
  final int? idoperador;
  final String? observaciones;
  final bool locked;
  final int? cobrador;
  final String? corregido;
  final double? tipocambio;
  final double? base;

  ValorTesoreria({
    required this.id,
    this.idtransaccionOrigen,
    this.tipoMovimiento,
    this.idconceptoTesoreria,
    this.fechaEmision,
    this.vencimiento,
    this.banco,
    this.cuenta,
    this.sucursal,
    this.numero,
    this.numeroInterno,
    this.firma,
    required this.importe,
    required this.cancelado,
    this.idoperador,
    this.observaciones,
    required this.locked,
    this.cobrador,
    this.corregido,
    this.tipocambio,
    this.base,
  });

  factory ValorTesoreria.fromJson(Map<String, dynamic> json) {
    return ValorTesoreria(
      id: json['id'] as int,
      idtransaccionOrigen: json['idtransaccion_origen'] as int?,
      tipoMovimiento: json['tipo_movimiento'] as int?,
      idconceptoTesoreria: json['idconcepto_tesoreria'] as int?,
      fechaEmision: json['fecha_emision'] != null
          ? DateTime.parse(json['fecha_emision'] as String)
          : null,
      vencimiento: json['vencimiento'] != null
          ? DateTime.parse(json['vencimiento'] as String)
          : null,
      banco: json['banco'] as String?,
      cuenta: json['cuenta'] as int?,
      sucursal: json['sucursal'] as int?,
      numero: json['numero'] as int?,
      numeroInterno: json['numero_interno'] as int?,
      firma: json['firma'] as String?,
      importe: (json['importe'] as num?)?.toDouble() ?? 0.0,
      cancelado: (json['cancelado'] as num?)?.toDouble() ?? 0.0,
      idoperador: json['idoperador'] as int?,
      observaciones: json['observaciones'] as String?,
      locked: json['locked'] as bool? ?? false,
      cobrador: json['cobrador'] as int?,
      corregido: json['corregido'] as String?,
      tipocambio: (json['tipocambio'] as num?)?.toDouble(),
      base: (json['base'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idtransaccion_origen': idtransaccionOrigen,
      'tipo_movimiento': tipoMovimiento,
      'idconcepto_tesoreria': idconceptoTesoreria,
      'fecha_emision': fechaEmision?.toIso8601String(),
      'vencimiento': vencimiento?.toIso8601String(),
      'banco': banco,
      'cuenta': cuenta,
      'sucursal': sucursal,
      'numero': numero,
      'numero_interno': numeroInterno,
      'firma': firma,
      'importe': importe,
      'cancelado': cancelado,
      'idoperador': idoperador,
      'observaciones': observaciones,
      'locked': locked,
      'cobrador': cobrador,
      'corregido': corregido,
      'tipocambio': tipocambio,
      'base': base,
    };
  }

  /// Saldo pendiente del valor
  double get saldoPendiente => importe - cancelado;

  /// Indica si el valor está totalmente cancelado
  bool get estaCancelado => saldoPendiente <= 0;
}
