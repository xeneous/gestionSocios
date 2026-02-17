class RecertificacionModel {
  final int? id;
  final int socioId;
  final DateTime fechaRecertificacion;
  final String titulo;
  final String estado; // 'Iniciada', 'En proceso', 'Finalizada'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RecertificacionModel({
    this.id,
    required this.socioId,
    required this.fechaRecertificacion,
    required this.titulo,
    required this.estado,
    this.createdAt,
    this.updatedAt,
  });

  factory RecertificacionModel.fromJson(Map<String, dynamic> json) {
    return RecertificacionModel(
      id: json['id'] as int?,
      socioId: json['socio_id'] as int,
      fechaRecertificacion: DateTime.parse(json['fecha_recertificacion'] as String),
      titulo: json['titulo'] as String,
      estado: json['estado'] as String,
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
      'socio_id': socioId,
      'fecha_recertificacion': fechaRecertificacion.toIso8601String().split('T')[0],
      'titulo': titulo,
      'estado': estado,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  RecertificacionModel copyWith({
    int? id,
    int? socioId,
    DateTime? fechaRecertificacion,
    String? titulo,
    String? estado,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecertificacionModel(
      id: id ?? this.id,
      socioId: socioId ?? this.socioId,
      fechaRecertificacion: fechaRecertificacion ?? this.fechaRecertificacion,
      titulo: titulo ?? this.titulo,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Estados disponibles como constantes
class EstadoRecertificacion {
  static const String iniciada = 'Iniciada';
  static const String enProceso = 'En proceso';
  static const String finalizada = 'Finalizada';

  static List<String> get todos => [iniciada, enProceso, finalizada];
}
