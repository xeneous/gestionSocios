/// Modelo para valores históricos de cuota social
class ValorCuotaSocial {
  final int id;
  final int anioMesInicio;
  final int? anioMesCierre;
  final double valorResidente;
  final double valorTitular;
  final DateTime createdAt;
  final DateTime updatedAt;

  ValorCuotaSocial({
    required this.id,
    required this.anioMesInicio,
    this.anioMesCierre,
    required this.valorResidente,
    required this.valorTitular,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ValorCuotaSocial.fromJson(Map<String, dynamic> json) {
    return ValorCuotaSocial(
      id: json['id'] as int,
      anioMesInicio: json['anio_mes_inicio'] as int,
      anioMesCierre: json['anio_mes_cierre'] as int?,
      valorResidente: (json['valor_residente'] as num).toDouble(),
      valorTitular: (json['valor_titular'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'anio_mes_inicio': anioMesInicio,
      'anio_mes_cierre': anioMesCierre,
      'valor_residente': valorResidente,
      'valor_titular': valorTitular,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Obtiene el valor correspondiente según si es residente o no
  double getValor(bool esResidente) {
    return esResidente ? valorResidente : valorTitular;
  }

  /// Convierte YYYYMM a DateTime (primer día del mes)
  static DateTime anioMesToDate(int anioMes) {
    final anio = anioMes ~/ 100;
    final mes = anioMes % 100;
    return DateTime(anio, mes, 1);
  }

  /// Convierte DateTime a YYYYMM
  static int dateToAnioMes(DateTime date) {
    return date.year * 100 + date.month;
  }

  /// Formatea YYYYMM a string legible (ej: "Enero 2026")
  static String formatAnioMes(int anioMes) {
    final date = anioMesToDate(anioMes);
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${meses[date.month - 1]} ${date.year}';
  }
}

/// Item de cuota social para cargar (usado en el diálogo)
class CuotaSocialItem {
  final int anioMes;
  double valor;
  bool incluir;
  bool esPromocion; // true si aplica descuento 50% primer año (concepto CRP)

  CuotaSocialItem({
    required this.anioMes,
    required this.valor,
    this.incluir = true,
    this.esPromocion = false,
  });

  /// Retorna el concepto según si es promoción o no
  String get concepto => esPromocion ? 'CRP' : 'CS';

  String get periodoTexto => ValorCuotaSocial.formatAnioMes(anioMes);
}
