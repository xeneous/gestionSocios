/// Modelo para representar un mes/año para facturación
class PeriodoFacturacion {
  final int anio;
  final int mes;

  PeriodoFacturacion({required this.anio, required this.mes});

  /// Convierte a formato YYYYMM (ej: 202401 para Enero 2024)
  int get anioMes => anio * 100 + mes;

  /// Nombre del mes en español
  String get nombreMes {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return meses[mes - 1];
  }

  String get displayText => '$nombreMes $anio';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodoFacturacion &&
          runtimeType == other.runtimeType &&
          anio == other.anio &&
          mes == other.mes;

  @override
  int get hashCode => anio.hashCode ^ mes.hashCode;

  @override
  String toString() => displayText;
}

/// Modelo para la vista previa de facturación
class ItemFacturacionPrevia {
  final int socioId;
  final String socioNombre;
  final String socioGrupo;
  final bool residente;
  final List<PeriodoFacturacion> mesesFaltantes;
  final double importeTotal;

  ItemFacturacionPrevia({
    required this.socioId,
    required this.socioNombre,
    required this.socioGrupo,
    required this.residente,
    required this.mesesFaltantes,
    required this.importeTotal,
  });

  int get cantidadMeses => mesesFaltantes.length;
}

/// Resumen de la facturación previa
class ResumenFacturacion {
  final List<ItemFacturacionPrevia> items;
  final int totalSocios;
  final int totalCuotas;
  final double totalImporte;

  ResumenFacturacion({
    required this.items,
    required this.totalSocios,
    required this.totalCuotas,
    required this.totalImporte,
  });
}
