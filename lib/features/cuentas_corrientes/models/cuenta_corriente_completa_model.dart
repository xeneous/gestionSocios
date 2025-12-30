import 'cuenta_corriente_model.dart';
import 'detalle_cuenta_corriente_model.dart';

/// Representa una transacción completa con header + items
/// Similar a AsientoCompleto del módulo de asientos
class CuentaCorrienteCompleta {
  final CuentaCorriente header;
  final List<DetalleCuentaCorriente> items;

  CuentaCorrienteCompleta({
    required this.header,
    required this.items,
  });

  // Computed properties
  double get totalItems => items.fold(0.0, (sum, item) => sum + item.importeTotal);

  bool get isValid {
    // Validar que el total de items coincida con el importe del header
    if (header.importe == null) return false;
    return (totalItems - header.importe!).abs() < 0.01;
  }

  int get cantidadItems => items.length;

  /// Obtiene una descripción resumida de los conceptos
  String get conceptosResumen {
    if (items.isEmpty) return 'Sin items';
    if (items.length == 1) return items.first.conceptoDescripcion ?? items.first.concepto;
    return '${items.first.conceptoDescripcion ?? items.first.concepto} + ${items.length - 1} más';
  }
}
