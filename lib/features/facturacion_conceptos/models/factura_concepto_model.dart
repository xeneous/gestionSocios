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
  final int? socioId;
  final int? profesionalId;
  final int entidadId; // 0 = Socios, 1 = Profesionales
  final String entidadNombre;
  final DateTime fecha;
  final DateTime? vencimiento;
  final List<ItemFacturaConcepto> items;

  NuevaFacturaConcepto({
    this.socioId,
    this.profesionalId,
    required this.entidadId,
    required this.entidadNombre,
    required this.fecha,
    this.vencimiento,
    required this.items,
  }) : assert(
          (entidadId == 0 && socioId != null) ||
              (entidadId == 1 && profesionalId != null),
          'socioId requerido para entidad 0, profesionalId para entidad 1',
        );

  // Constructor de conveniencia para socios (retrocompatibilidad)
  factory NuevaFacturaConcepto.paraSocio({
    required int socioId,
    required String socioNombre,
    required DateTime fecha,
    DateTime? vencimiento,
    required List<ItemFacturaConcepto> items,
  }) {
    return NuevaFacturaConcepto(
      socioId: socioId,
      entidadId: 0,
      entidadNombre: socioNombre,
      fecha: fecha,
      vencimiento: vencimiento,
      items: items,
    );
  }

  // Constructor de conveniencia para profesionales
  factory NuevaFacturaConcepto.paraProfesional({
    required int profesionalId,
    required String profesionalNombre,
    required DateTime fecha,
    DateTime? vencimiento,
    required List<ItemFacturaConcepto> items,
  }) {
    return NuevaFacturaConcepto(
      profesionalId: profesionalId,
      entidadId: 1,
      entidadNombre: profesionalNombre,
      fecha: fecha,
      vencimiento: vencimiento,
      items: items,
    );
  }

  // Getter para nombre (retrocompatibilidad)
  String get socioNombre => entidadNombre;

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
