class ProfesionalModel {
  final int? id;

  // Datos Personales
  final String apellido;
  final String nombre;
  final String? tipoDocumento;
  final String? numeroDocumento;
  final String? cuil;
  final int? nacionalidadId;
  final String? sexo;
  final DateTime? fechaNacimiento;

  // Datos Profesionales
  final String? grupo;
  final DateTime? grupoDesde;
  final String? matriculaNacional;
  final String? matriculaProvincial;
  final String? especialidad;

  // Domicilio
  final String? domicilio;
  final String? localidad;
  final int? provinciaId;
  final String? codigoPostal;
  final int? paisId;
  final String? telefono;
  final String? telefonoSecundario;

  // Contacto Email
  final String? email;
  final String? emailAlternativo;

  // Débito Automático
  final int? tarjetaId;
  final String? numeroTarjeta;
  final bool adheridoDebito;
  final DateTime? vencimientoTarjeta;
  final DateTime? debitarDesde;

  // Estado
  final bool activo;
  final DateTime? fechaBaja;

  // Metadata
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProfesionalModel({
    this.id,
    required this.apellido,
    required this.nombre,
    this.tipoDocumento,
    this.numeroDocumento,
    this.cuil,
    this.nacionalidadId,
    this.sexo,
    this.fechaNacimiento,
    this.grupo,
    this.grupoDesde,
    this.matriculaNacional,
    this.matriculaProvincial,
    this.especialidad,
    this.domicilio,
    this.localidad,
    this.provinciaId,
    this.codigoPostal,
    this.paisId,
    this.telefono,
    this.telefonoSecundario,
    this.email,
    this.emailAlternativo,
    this.tarjetaId,
    this.numeroTarjeta,
    this.adheridoDebito = false,
    this.vencimientoTarjeta,
    this.debitarDesde,
    this.activo = true,
    this.fechaBaja,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfesionalModel.fromJson(Map<String, dynamic> json) {
    return ProfesionalModel(
      id: json['id'] as int?,
      apellido: json['apellido'] as String,
      nombre: json['nombre'] as String,
      tipoDocumento: json['tipo_documento'] as String?,
      numeroDocumento: json['numero_documento'] as String?,
      cuil: json['cuil'] as String?,
      nacionalidadId: json['nacionalidad_id'] as int?,
      sexo: json['sexo'] as String?,
      fechaNacimiento: json['fecha_nacimiento'] != null
          ? DateTime.parse(json['fecha_nacimiento'] as String)
          : null,
      grupo: json['grupo'] as String?,
      grupoDesde: json['grupo_desde'] != null
          ? DateTime.parse(json['grupo_desde'] as String)
          : null,
      matriculaNacional: json['matricula_nacional'] as String?,
      matriculaProvincial: json['matricula_provincial'] as String?,
      especialidad: json['especialidad'] as String?,
      domicilio: json['domicilio'] as String?,
      localidad: json['localidad'] as String?,
      provinciaId: json['provincia_id'] as int?,
      codigoPostal: json['codigo_postal'] as String?,
      paisId: json['pais_id'] as int?,
      telefono: json['telefono'] as String?,
      telefonoSecundario: json['telefono_secundario'] as String?,
      email: json['email'] as String?,
      emailAlternativo: json['email_alternativo'] as String?,
      tarjetaId: json['tarjeta_id'] as int?,
      numeroTarjeta: json['numero_tarjeta'] as String?,
      adheridoDebito: json['adherido_debito'] as bool? ?? false,
      vencimientoTarjeta: json['vencimiento_tarjeta'] != null
          ? DateTime.parse(json['vencimiento_tarjeta'] as String)
          : null,
      debitarDesde: json['debitar_desde'] != null
          ? DateTime.parse(json['debitar_desde'] as String)
          : null,
      activo: json['activo'] as bool? ?? true,
      fechaBaja: json['fecha_baja'] != null
          ? DateTime.parse(json['fecha_baja'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'apellido': apellido,
      'nombre': nombre,
      'tipo_documento': tipoDocumento,
      'numero_documento': numeroDocumento,
      'cuil': cuil,
      'nacionalidad_id': nacionalidadId,
      'sexo': sexo,
      'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T')[0],
      'grupo': grupo,
      'grupo_desde': grupoDesde?.toIso8601String().split('T')[0],
      'matricula_nacional': matriculaNacional,
      'matricula_provincial': matriculaProvincial,
      'especialidad': especialidad,
      'domicilio': domicilio,
      'localidad': localidad,
      'provincia_id': provinciaId,
      'codigo_postal': codigoPostal,
      'pais_id': paisId,
      'telefono': telefono,
      'telefono_secundario': telefonoSecundario,
      'email': email,
      'email_alternativo': emailAlternativo,
      'tarjeta_id': tarjetaId,
      'numero_tarjeta': numeroTarjeta,
      'adherido_debito': adheridoDebito,
      'vencimiento_tarjeta': vencimientoTarjeta?.toIso8601String().split('T')[0],
      'debitar_desde': debitarDesde?.toIso8601String().split('T')[0],
      'activo': activo,
      'fecha_baja': fechaBaja?.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  ProfesionalModel copyWith({
    int? id,
    String? apellido,
    String? nombre,
    String? tipoDocumento,
    String? numeroDocumento,
    String? cuil,
    int? nacionalidadId,
    String? sexo,
    DateTime? fechaNacimiento,
    String? grupo,
    DateTime? grupoDesde,
    String? matriculaNacional,
    String? matriculaProvincial,
    String? especialidad,
    String? domicilio,
    String? localidad,
    int? provinciaId,
    String? codigoPostal,
    int? paisId,
    String? telefono,
    String? telefonoSecundario,
    String? email,
    String? emailAlternativo,
    int? tarjetaId,
    String? numeroTarjeta,
    bool? adheridoDebito,
    DateTime? vencimientoTarjeta,
    DateTime? debitarDesde,
    bool? activo,
    DateTime? fechaBaja,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfesionalModel(
      id: id ?? this.id,
      apellido: apellido ?? this.apellido,
      nombre: nombre ?? this.nombre,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      cuil: cuil ?? this.cuil,
      nacionalidadId: nacionalidadId ?? this.nacionalidadId,
      sexo: sexo ?? this.sexo,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      grupo: grupo ?? this.grupo,
      grupoDesde: grupoDesde ?? this.grupoDesde,
      matriculaNacional: matriculaNacional ?? this.matriculaNacional,
      matriculaProvincial: matriculaProvincial ?? this.matriculaProvincial,
      especialidad: especialidad ?? this.especialidad,
      domicilio: domicilio ?? this.domicilio,
      localidad: localidad ?? this.localidad,
      provinciaId: provinciaId ?? this.provinciaId,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      paisId: paisId ?? this.paisId,
      telefono: telefono ?? this.telefono,
      telefonoSecundario: telefonoSecundario ?? this.telefonoSecundario,
      email: email ?? this.email,
      emailAlternativo: emailAlternativo ?? this.emailAlternativo,
      tarjetaId: tarjetaId ?? this.tarjetaId,
      numeroTarjeta: numeroTarjeta ?? this.numeroTarjeta,
      adheridoDebito: adheridoDebito ?? this.adheridoDebito,
      vencimientoTarjeta: vencimientoTarjeta ?? this.vencimientoTarjeta,
      debitarDesde: debitarDesde ?? this.debitarDesde,
      activo: activo ?? this.activo,
      fechaBaja: fechaBaja ?? this.fechaBaja,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get nombreCompleto => '$apellido, $nombre';
}
