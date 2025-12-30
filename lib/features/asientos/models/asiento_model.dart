class AsientoHeader {
  final int? id;
  final int asiento;
  final int anioMes;
  final int tipoAsiento;
  final DateTime fecha;
  final String? detalle;
  final int? centroCosto;

  AsientoHeader({
    this.id,
    required this.asiento,
    required this.anioMes,
    required this.tipoAsiento,
    required this.fecha,
    this.detalle,
    this.centroCosto,
  });

  factory AsientoHeader.fromJson(Map<String, dynamic> json) => AsientoHeader(
        id: json['id'],
        asiento: json['asiento'],
        anioMes: json['anio_mes'],
        tipoAsiento: json['tipo_asiento'],
        fecha: DateTime.parse(json['fecha']),
        detalle: json['detalle'],
        centroCosto: json['centro_costo'],
      );

  Map<String, dynamic> toJson() => {
        'asiento': asiento,
        'anio_mes': anioMes,
        'tipo_asiento': tipoAsiento,
        'fecha': fecha.toIso8601String().split('T')[0],
        'detalle': detalle,
        'centro_costo': centroCosto,
      };
}

class AsientoItem {
  final int? id;
  final int asiento;
  final int anioMes;
  final int tipoAsiento;
  final int item;
  final int cuentaId;
  final double debe;
  final double haber;
  final String? observacion;
  final int? centroCosto;
  
  // Para UI - nombre de cuenta
  String? cuentaDescripcion;
  int? cuentaNumero;

  AsientoItem({
    this.id,
    required this.asiento,
    required this.anioMes,
    required this.tipoAsiento,
    required this.item,
    required this.cuentaId,
    this.debe = 0.0,
    this.haber = 0.0,
    this.observacion,
    this.centroCosto,
    this.cuentaDescripcion,
    this.cuentaNumero,
  });

  factory AsientoItem.fromJson(Map<String, dynamic> json) => AsientoItem(
        id: json['id'],
        asiento: json['asiento'],
        anioMes: json['anio_mes'],
        tipoAsiento: json['tipo_asiento'],
        item: json['item'],
        cuentaId: json['cuenta_id'],
        debe: (json['debe'] ?? 0).toDouble(),
        haber: (json['haber'] ?? 0).toDouble(),
        observacion: json['observacion'],
        centroCosto: json['centro_costo'],
        cuentaDescripcion: json['cuenta_descripcion'],
        cuentaNumero: json['cuenta_numero'],
      );

  Map<String, dynamic> toJson() => {
        'asiento': asiento,
        'anio_mes': anioMes,
        'tipo_asiento': tipoAsiento,
        'item': item,
        'cuenta_id': cuentaId,
        'debe': debe,
        'haber': haber,
        'observacion': observacion,
        'centro_costo': centroCosto,
      };

  AsientoItem copyWith({
    int? id,
    int? cuentaId,
    double? debe,
    double? haber,
    String? observacion,
    String? cuentaDescripcion,
    int? cuentaNumero,
  }) {
    return AsientoItem(
      id: id ?? this.id,
      asiento: asiento,
      anioMes: anioMes,
      tipoAsiento: tipoAsiento,
      item: item,
      cuentaId: cuentaId ?? this.cuentaId,
      debe: debe ?? this.debe,
      haber: haber ?? this.haber,
      observacion: observacion ?? this.observacion,
      centroCosto: centroCosto,
      cuentaDescripcion: cuentaDescripcion ?? this.cuentaDescripcion,
      cuentaNumero: cuentaNumero ?? this.cuentaNumero,
    );
  }
}

// Clase para manejar asiento completo
class AsientoCompleto {
  final AsientoHeader header;
  final List<AsientoItem> items;

  AsientoCompleto({
    required this.header,
    required this.items,
  });

  double get totalDebe => items.fold(0.0, (sum, item) => sum + item.debe);
  double get totalHaber => items.fold(0.0, (sum, item) => sum + item.haber);
  bool get isBalanced => (totalDebe - totalHaber).abs() < 0.01;
}
