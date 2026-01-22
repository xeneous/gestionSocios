class Socio {
  final int? id;
  
  // Datos Personales
  final String apellido;
  final String nombre;
  final String? tipoDocumento;
  final String? numeroDocumento;
  final String? cuil;
  final int? sexo;
  final DateTime? fechaNacimiento;
  
  // Datos Profesionales
  final String? grupo;
  final DateTime? grupoDesde;
  final bool residente;
  final DateTime? fechaInicioResidencia;
  final bool descuentoPrimerAnio;
  final DateTime? fechaFinDescuento;
  final String? matriculaNacional;
  final String? matriculaProvincial;
  final DateTime? fechaIngreso;
  
  // Domicilio
  final String? domicilio;
  final String? localidad;
  final int? provinciaId;
  final int? paisId;
  final String? codigoPostal;
  
  // Contacto
  final String? telefono;
  final String? telefonoSecundario;
  final String? celular;
  final String? email;
  final String? emailAlternativo;
  
  // Débito Automático
  final int? tarjetaId;
  final String? numeroTarjeta;
  final bool adheridoDebito;
  final DateTime? vencimientoTarjeta;
  final DateTime? debitarDesde;
  
  // Metadata
  final DateTime? fechaBaja;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Socio({
    this.id,
    required this.apellido,
    required this.nombre,
    this.tipoDocumento = 'DNI',
    this.numeroDocumento,
    this.cuil,
    this.sexo,
    this.fechaNacimiento,
    this.grupo,
    this.grupoDesde,
    this.residente = false,
    this.fechaInicioResidencia,
    this.descuentoPrimerAnio = false,
    this.fechaFinDescuento,
    this.matriculaNacional,
    this.matriculaProvincial,
    this.fechaIngreso,
    this.domicilio,
    this.localidad,
    this.provinciaId,
    this.paisId,
    this.codigoPostal,
    this.telefono,
    this.telefonoSecundario,
    this.celular,
    this.email,
    this.emailAlternativo,
    this.tarjetaId,
    this.numeroTarjeta,
    this.adheridoDebito = false,
    this.vencimientoTarjeta,
    this.debitarDesde,
    this.fechaBaja,
    this.createdAt,
    this.updatedAt,
  });

  String get nombreCompleto => '$apellido, $nombre';

  factory Socio.fromJson(Map<String, dynamic> json) {
    return Socio(
      id: json['id'] as int?,
      apellido: json['apellido'] as String,
      nombre: json['nombre'] as String,
      tipoDocumento: json['tipo_documento'] as String?,
      numeroDocumento: json['numero_documento'] as String?,
      cuil: json['cuil'] as String?,
      sexo: json['sexo'] is String 
          ? int.tryParse(json['sexo'] as String) 
          : json['sexo'] as int?,
      fechaNacimiento: json['fecha_nacimiento'] != null
          ? DateTime.parse(json['fecha_nacimiento'])
          : null,
      grupo: json['grupo'] as String?,
      grupoDesde: json['grupo_desde'] != null
          ? DateTime.parse(json['grupo_desde'])
          : null,
      residente: json['residente'] as bool? ?? false,
      fechaInicioResidencia: json['fecha_inicio_residencia'] != null
          ? DateTime.parse(json['fecha_inicio_residencia'])
          : null,
      descuentoPrimerAnio: json['descuento_primer_anio'] as bool? ?? false,
      fechaFinDescuento: json['fecha_fin_descuento'] != null
          ? DateTime.parse(json['fecha_fin_descuento'])
          : null,
      matriculaNacional: json['matricula_nacional'] as String?,
      matriculaProvincial: json['matricula_provincial'] as String?,
      fechaIngreso: json['fecha_ingreso'] != null
          ? DateTime.parse(json['fecha_ingreso'])
          : null,
      domicilio: json['domicilio'] as String?,
      localidad: json['localidad'] as String?,
      provinciaId: json['provincia_id'] as int?,
      paisId: json['pais_id'] as int?,
      codigoPostal: json['codigo_postal'] as String?,
      telefono: json['telefono'] as String?,
      telefonoSecundario: json['telefono_secundario'] as String?,
      celular: json['celular'] as String?,
      email: json['email'] as String?,
      emailAlternativo: json['email_alternativo'] as String?,
      tarjetaId: json['tarjeta_id'] as int?,
      numeroTarjeta: json['numero_tarjeta'] as String?,
      adheridoDebito: json['adherido_debito'] as bool? ?? false,
      vencimientoTarjeta: json['vencimiento_tarjeta'] != null
          ? DateTime.parse(json['vencimiento_tarjeta'])
          : null,
      debitarDesde: json['debitar_desde'] != null
          ? DateTime.parse(json['debitar_desde'])
          : null,
      fechaBaja: json['fecha_baja'] != null
          ? DateTime.parse(json['fecha_baja'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
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
      'sexo': sexo,
      'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T')[0],
      'grupo': grupo,
      'grupo_desde': grupoDesde?.toIso8601String().split('T')[0],
      'residente': residente,
      'fecha_inicio_residencia': fechaInicioResidencia?.toIso8601String().split('T')[0],
      'descuento_primer_anio': descuentoPrimerAnio,
      'fecha_fin_descuento': fechaFinDescuento?.toIso8601String().split('T')[0],
      'matricula_nacional': matriculaNacional,
      'matricula_provincial': matriculaProvincial,
      'fecha_ingreso': fechaIngreso?.toIso8601String().split('T')[0],
      'domicilio': domicilio,
      'localidad': localidad,
      'provincia_id': provinciaId,
      'pais_id': paisId,
      'codigo_postal': codigoPostal,
      'telefono': telefono,
      'telefono_secundario': telefonoSecundario,
      'celular': celular,
      'email': email,
      'email_alternativo': emailAlternativo,
      'tarjeta_id': tarjetaId,
      'numero_tarjeta': numeroTarjeta,
      'adherido_debito': adheridoDebito,
      'vencimiento_tarjeta': vencimientoTarjeta?.toIso8601String().split('T')[0],
      'debitar_desde': debitarDesde?.toIso8601String().split('T')[0],
      'fecha_baja': fechaBaja?.toIso8601String(),
    };
  }

  Socio copyWith({
    int? id,
    String? apellido,
    String? nombre,
    String? tipoDocumento,
    String? numeroDocumento,
    String? cuil,
    int? sexo,
    DateTime? fechaNacimiento,
    String? grupo,
    DateTime? grupoDesde,
    bool? residente,
    DateTime? fechaInicioResidencia,
    bool? descuentoPrimerAnio,
    DateTime? fechaFinDescuento,
    String? matriculaNacional,
    String? matriculaProvincial,
    DateTime? fechaIngreso,
    String? domicilio,
    String? localidad,
    int? provinciaId,
    int? paisId,
    String? codigoPostal,
    String? telefono,
    String? telefonoSecundario,
    String? celular,
    String? email,
    String? emailAlternativo,
    int? tarjetaId,
    String? numeroTarjeta,
    bool? adheridoDebito,
    DateTime? vencimientoTarjeta,
    DateTime? debitarDesde,
    DateTime? fechaBaja,
  }) {
    return Socio(
      id: id ?? this.id,
      apellido: apellido ?? this.apellido,
      nombre: nombre ?? this.nombre,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      cuil: cuil ?? this.cuil,
      sexo: sexo ?? this.sexo,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      grupo: grupo ?? this.grupo,
      grupoDesde: grupoDesde ?? this.grupoDesde,
      residente: residente ?? this.residente,
      fechaInicioResidencia: fechaInicioResidencia ?? this.fechaInicioResidencia,
      descuentoPrimerAnio: descuentoPrimerAnio ?? this.descuentoPrimerAnio,
      fechaFinDescuento: fechaFinDescuento ?? this.fechaFinDescuento,
      matriculaNacional: matriculaNacional ?? this.matriculaNacional,
      matriculaProvincial: matriculaProvincial ?? this.matriculaProvincial,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      domicilio: domicilio ?? this.domicilio,
      localidad: localidad ?? this.localidad,
      provinciaId: provinciaId ?? this.provinciaId,
      paisId: paisId ?? this.paisId,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      telefono: telefono ?? this.telefono,
      telefonoSecundario: telefonoSecundario ?? this.telefonoSecundario,
      celular: celular ?? this.celular,
      email: email ?? this.email,
      emailAlternativo: emailAlternativo ?? this.emailAlternativo,
      tarjetaId: tarjetaId ?? this.tarjetaId,
      numeroTarjeta: numeroTarjeta ?? this.numeroTarjeta,
      adheridoDebito: adheridoDebito ?? this.adheridoDebito,
      vencimientoTarjeta: vencimientoTarjeta ?? this.vencimientoTarjeta,
      debitarDesde: debitarDesde ?? this.debitarDesde,
      fechaBaja: fechaBaja ?? this.fechaBaja,
    );
  }
}
