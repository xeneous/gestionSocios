class Cliente {
  final int? codigo;
  final String? razonSocial;
  final String? nombre;
  final String? apellido;
  final String? domicilio;
  final String? localidad;
  final String? codigoPostal;
  final int? idProvincia;
  final String? cuit;
  final int? civa;
  final String? mail;
  final String? telefono1;
  final String? telefono2;
  final String? notas;
  final int? activo;
  final DateTime? fecha;
  final DateTime? fechaBaja;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Cliente({
    this.codigo,
    this.razonSocial,
    this.nombre,
    this.apellido,
    this.domicilio,
    this.localidad,
    this.codigoPostal,
    this.idProvincia,
    this.cuit,
    this.civa,
    this.mail,
    this.telefono1,
    this.telefono2,
    this.notas,
    this.activo = 1,
    this.fecha,
    this.fechaBaja,
    this.createdAt,
    this.updatedAt,
  });

  String get nombreCompleto {
    if (razonSocial != null && razonSocial!.isNotEmpty) {
      return razonSocial!;
    }
    if (apellido != null && nombre != null) {
      return '$apellido, $nombre';
    }
    return apellido ?? nombre ?? 'Sin nombre';
  }

  bool get esActivo => activo == 1 && fechaBaja == null;

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      codigo: json['codigo'] as int?,
      razonSocial: json['razon_social'] as String?,
      nombre: json['nombre'] as String?,
      apellido: json['apellido'] as String?,
      domicilio: json['domicilio'] as String?,
      localidad: json['localidad'] as String?,
      codigoPostal: json['codigo_postal'] as String?,
      idProvincia: json['id_provincia'] as int?,
      cuit: json['cuit'] as String?,
      civa: json['civa'] as int?,
      mail: json['mail'] as String?,
      telefono1: json['telefono1'] as String?,
      telefono2: json['telefono2'] as String?,
      notas: json['notas'] as String?,
      activo: json['activo'] as int? ?? 1,
      fecha: json['fecha'] != null ? DateTime.tryParse(json['fecha'].toString()) : null,
      fechaBaja: json['fecha_baja'] != null ? DateTime.tryParse(json['fecha_baja'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (codigo != null) 'codigo': codigo,
      'razon_social': razonSocial,
      'nombre': nombre,
      'apellido': apellido,
      'domicilio': domicilio,
      'localidad': localidad,
      'codigo_postal': codigoPostal,
      'id_provincia': idProvincia,
      'cuit': cuit,
      'civa': civa,
      'mail': mail,
      'telefono1': telefono1,
      'telefono2': telefono2,
      'notas': notas,
      'activo': activo,
      if (fecha != null) 'fecha': fecha!.toIso8601String(),
      if (fechaBaja != null) 'fecha_baja': fechaBaja!.toIso8601String(),
    };
  }

  Cliente copyWith({
    int? codigo,
    String? razonSocial,
    String? nombre,
    String? apellido,
    String? domicilio,
    String? localidad,
    String? codigoPostal,
    int? idProvincia,
    String? cuit,
    int? civa,
    String? mail,
    String? telefono1,
    String? telefono2,
    String? notas,
    int? activo,
    DateTime? fecha,
    DateTime? fechaBaja,
  }) {
    return Cliente(
      codigo: codigo ?? this.codigo,
      razonSocial: razonSocial ?? this.razonSocial,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      domicilio: domicilio ?? this.domicilio,
      localidad: localidad ?? this.localidad,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      idProvincia: idProvincia ?? this.idProvincia,
      cuit: cuit ?? this.cuit,
      civa: civa ?? this.civa,
      mail: mail ?? this.mail,
      telefono1: telefono1 ?? this.telefono1,
      telefono2: telefono2 ?? this.telefono2,
      notas: notas ?? this.notas,
      activo: activo ?? this.activo,
      fecha: fecha ?? this.fecha,
      fechaBaja: fechaBaja ?? this.fechaBaja,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
