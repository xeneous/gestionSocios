/// Item de línea para factura de conceptos
class ItemFacturaConcepto {
  final String concepto;
  final String? descripcion;
  int cantidad;
  double precioUnitario;

  ItemFacturaConcepto({
    required this.concepto,
    this.descripcion,
    this.cantidad = 1,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;

  Map<String, dynamic> toDetalleJson(int idtransaccion, int item) => {
        'idtransaccion': idtransaccion,
        'item': item,
        'concepto': concepto,
        'cantidad': cantidad,
        'importe': precioUnitario,
      };
}

/// Modelo para crear una factura de conceptos
class NuevaFacturaConcepto {
  final int socioId;
  final String socioNombre;
  final DateTime fecha;
  final DateTime? vencimiento;
  final List<ItemFacturaConcepto> items;

  NuevaFacturaConcepto({
    required this.socioId,
    required this.socioNombre,
    required this.fecha,
    this.vencimiento,
    required this.items,
  });

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);

  int get cantidadItems => items.length;

  /// Genera el número de documento (YYYYMMDD + secuencial)
  String generarDocumentoNumero(int secuencial) {
    final fechaStr =
        '${fecha.year}${fecha.month.toString().padLeft(2, '0')}${fecha.day.toString().padLeft(2, '0')}';
    return '$fechaStr-${secuencial.toString().padLeft(4, '0')}';
  }
}

/// Factura creada (response)
class FacturaConceptoCreada {
  final int idtransaccion;
  final String documentoNumero;
  final double importe;

  FacturaConceptoCreada({
    required this.idtransaccion,
    required this.documentoNumero,
    required this.importe,
  });
}
