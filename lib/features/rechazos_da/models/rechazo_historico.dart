class RechazoHistorico {
  final int id;
  final int tarjetaId;
  final String nombreTarjeta;
  final int periodo; // YYYYMM
  final int socioId;
  final int entidadId;
  final String? apellido;
  final String? nombre;
  final String? email;
  final String? telefono;
  final double importe;
  final String? numeroTarjeta;
  final String? motivo;
  final DateTime? fechaRechazo;

  RechazoHistorico({
    required this.id,
    required this.tarjetaId,
    required this.nombreTarjeta,
    required this.periodo,
    required this.socioId,
    required this.entidadId,
    this.apellido,
    this.nombre,
    this.email,
    this.telefono,
    required this.importe,
    this.numeroTarjeta,
    this.motivo,
    this.fechaRechazo,
  });

  String get nombreCompleto {
    if (apellido == null && nombre == null) return 'Socio $socioId';
    return '${apellido ?? ''}, ${nombre ?? ''}'.trim();
  }

  String get numeroTarjetaEnmascarado {
    if (numeroTarjeta == null || numeroTarjeta!.isEmpty) return '-';
    final n = numeroTarjeta!.replaceAll(RegExp(r'[\s-]'), '');
    if (n.length >= 4) return 'XXXX-XXXX-XXXX-${n.substring(n.length - 4)}';
    return numeroTarjeta!;
  }

  factory RechazoHistorico.fromJson(
    Map<String, dynamic> json,
    Map<int, Map<String, dynamic>> sociosMap,
    Map<int, String> tarjetasMap,
  ) {
    final socioId = json['socio_id'] as int;
    final tarjetaId = json['tarjeta_id'] as int;
    final socio = sociosMap[socioId];
    return RechazoHistorico(
      id: json['id'] as int,
      tarjetaId: tarjetaId,
      nombreTarjeta: tarjetasMap[tarjetaId] ?? 'Tarjeta $tarjetaId',
      periodo: json['periodo'] as int,
      socioId: socioId,
      entidadId: json['entidad_id'] as int? ?? 0,
      apellido: socio?['apellido'] as String?,
      nombre: socio?['nombre'] as String?,
      email: socio?['email'] as String?,
      telefono: socio?['telefono'] as String?,
      importe: (json['importe'] as num).toDouble(),
      numeroTarjeta: json['numero_tarjeta'] as String?,
      motivo: json['motivo'] as String?,
      fechaRechazo: json['fecha_rechazo'] != null
          ? DateTime.parse(json['fecha_rechazo'] as String)
          : null,
    );
  }
}
