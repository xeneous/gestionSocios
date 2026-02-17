class ArchivoSocioModel {
  final int? id;
  final int socioId;
  final String nombre;
  final String storagePath;
  final String? tipoContenido;
  final int? tamanio;
  final String? descripcion;
  final DateTime? createdAt;

  ArchivoSocioModel({
    this.id,
    required this.socioId,
    required this.nombre,
    required this.storagePath,
    this.tipoContenido,
    this.tamanio,
    this.descripcion,
    this.createdAt,
  });

  factory ArchivoSocioModel.fromJson(Map<String, dynamic> json) {
    return ArchivoSocioModel(
      id: json['id'] as int?,
      socioId: json['socio_id'] as int,
      nombre: json['nombre'] as String,
      storagePath: json['storage_path'] as String,
      tipoContenido: json['tipo_contenido'] as String?,
      tamanio: json['tamanio'] != null ? (json['tamanio'] as num).toInt() : null,
      descripcion: json['descripcion'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'socio_id': socioId,
      'nombre': nombre,
      'storage_path': storagePath,
      if (tipoContenido != null) 'tipo_contenido': tipoContenido,
      if (tamanio != null) 'tamanio': tamanio,
      if (descripcion != null) 'descripcion': descripcion,
    };
  }

  /// Formatea el tamaño del archivo de forma legible
  String get tamanioFormateado {
    if (tamanio == null) return 'Desconocido';
    final bytes = tamanio!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Retorna un ícono apropiado según el tipo de contenido
  bool get esImagen =>
      tipoContenido?.startsWith('image/') ?? false;

  bool get esPdf => tipoContenido == 'application/pdf';
}
