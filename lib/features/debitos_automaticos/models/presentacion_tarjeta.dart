/// Modelo para la cabecera de una presentación de débito automático
class PresentacionTarjeta {
  final int id;
  final int tarjetaId;
  final String nombreTarjeta;
  final DateTime fechaPresentacion;
  final double total;
  final bool procesado;
  final DateTime? fechaAcreditacion;
  final double? comision;
  final double? neto;

  PresentacionTarjeta({
    required this.id,
    required this.tarjetaId,
    required this.nombreTarjeta,
    required this.fechaPresentacion,
    required this.total,
    required this.procesado,
    this.fechaAcreditacion,
    this.comision,
    this.neto,
  });

  factory PresentacionTarjeta.fromJson(Map<String, dynamic> json) {
    final tarjetaData = json['tarjetas'] as Map<String, dynamic>?;
    return PresentacionTarjeta(
      id: json['id'] as int,
      tarjetaId: json['tarjeta_id'] as int,
      nombreTarjeta:
          tarjetaData?['nombre'] as String? ?? 'Tarjeta ${json['tarjeta_id']}',
      fechaPresentacion:
          DateTime.parse(json['fecha_presentacion'] as String),
      total: (json['total'] as num).toDouble(),
      procesado: json['procesado'] as bool? ?? false,
      fechaAcreditacion: json['fecha_acreditacion'] != null
          ? DateTime.parse(json['fecha_acreditacion'] as String)
          : null,
      comision: (json['comision'] as num?)?.toDouble(),
      neto: (json['neto'] as num?)?.toDouble(),
    );
  }

  /// Período YYYYMM derivado de la fecha de presentación
  int get periodo =>
      fechaPresentacion.year * 100 + fechaPresentacion.month;
}

/// Modelo para una fila del detalle de una presentación
class DetallePresentacion {
  final int id;
  final int tarjetaId;
  final int periodo;
  final int socioId;
  final int entidadId;
  final double importe;
  final String? numeroTarjeta;
  final String apellido;
  final String nombre;

  DetallePresentacion({
    required this.id,
    required this.tarjetaId,
    required this.periodo,
    required this.socioId,
    required this.entidadId,
    required this.importe,
    this.numeroTarjeta,
    required this.apellido,
    required this.nombre,
  });

  factory DetallePresentacion.fromJson(
    Map<String, dynamic> json,
    Map<int, Map<String, dynamic>> sociosMap,
  ) {
    final socioId = json['socio_id'] as int;
    final socio = sociosMap[socioId];
    return DetallePresentacion(
      id: json['id'] as int,
      tarjetaId: json['tarjeta_id'] as int,
      periodo: json['periodo'] as int,
      socioId: socioId,
      entidadId: json['entidad_id'] as int? ?? 0,
      importe: (json['importe'] as num).toDouble(),
      numeroTarjeta: json['numero_tarjeta'] as String?,
      apellido: socio?['apellido'] as String? ?? '(Socio $socioId)',
      nombre: socio?['nombre'] as String? ?? '',
    );
  }

  String get nombreCompleto => '$apellido, $nombre'.trim();

  String get numeroTarjetaEnmascarado {
    if (numeroTarjeta == null || numeroTarjeta!.length < 4) return '****';
    final ultimos = numeroTarjeta!.substring(numeroTarjeta!.length - 4);
    return '****-****-****-$ultimos';
  }
}
