class SocioDeudaItem {
  final int socioId;
  final String apellido;
  final String nombre;
  final int mesesMora;
  final double importeTotal;
  final String? email;
  final bool adheridoDebito;
  final int? tarjetaId;
  final List<DeudaDetalle> detalles; // Para saber qué períodos debe

  SocioDeudaItem({
    required this.socioId,
    required this.apellido,
    required this.nombre,
    required this.mesesMora,
    required this.importeTotal,
    this.email,
    required this.adheridoDebito,
    this.tarjetaId,
    required this.detalles,
  });

  /// Obtiene la lista de períodos adeudados formateados
  String get periodosAdeudados {
    if (detalles.isEmpty) return '';
    return detalles
        .map((d) => _formatPeriodo(d.documentoNumero))
        .join(', ');
  }

  String _formatPeriodo(String anioMes) {
    if (anioMes.length != 6) return anioMes;
    final mes = anioMes.substring(4, 6);
    final anio = anioMes.substring(0, 4);
    return '$mes/$anio';
  }
}

/// Detalle de cada período adeudado
class DeudaDetalle {
  final String documentoNumero; // YYYYMM
  final double importe;
  final DateTime? vencimiento;

  DeudaDetalle({
    required this.documentoNumero,
    required this.importe,
    this.vencimiento,
  });
}
