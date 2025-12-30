class TipoDocumento {
  final String codigo;
  final String descripcion;

  TipoDocumento({
    required this.codigo,
    required this.descripcion,
  });

  static final List<TipoDocumento> opciones = [
    TipoDocumento(codigo: 'DNI', descripcion: 'Documento Nacional de Identidad'),
    TipoDocumento(codigo: 'LC', descripcion: 'Libreta Cívica'),
    TipoDocumento(codigo: 'LE', descripcion: 'Libreta de Enrolamiento'),
    TipoDocumento(codigo: 'PAS', descripcion: 'Pasaporte'),
  ];
}
