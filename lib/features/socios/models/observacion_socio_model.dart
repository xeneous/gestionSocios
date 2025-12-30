class ObservacionSocio {
  final int? id;
  final int socioId;
  final DateTime fecha;
  final String observacion;
  final String? usuario;

  ObservacionSocio({
    this.id,
    required this.socioId,
    required this.fecha,
    required this.observacion,
    this.usuario,
  });

  factory ObservacionSocio.fromJson(Map<String, dynamic> json) =>
      ObservacionSocio(
        id: json['id'],
        socioId: json['socio_id'],
        fecha: DateTime.parse(json['fecha']),
        observacion: json['observacion'],
        usuario: json['usuario'],
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'socio_id': socioId,
        'fecha': fecha.toIso8601String(),
        'observacion': observacion,
        'usuario': usuario,
      };

  ObservacionSocio copyWith({
    int? id,
    int? socioId,
    DateTime? fecha,
    String? observacion,
    String? usuario,
  }) {
    return ObservacionSocio(
      id: id ?? this.id,
      socioId: socioId ?? this.socioId,
      fecha: fecha ?? this.fecha,
      observacion: observacion ?? this.observacion,
      usuario: usuario ?? this.usuario,
    );
  }
}
