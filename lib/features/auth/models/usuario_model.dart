import '../../../core/models/user_role.dart';

/// Modelo de usuario (tabla usuarios)
class Usuario {
  final String id; // UUID del usuario (FK a auth.users)
  final String email;
  final String? nombre;
  final String? apellido;
  final UserRole rol;
  final bool activo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Usuario({
    required this.id,
    required this.email,
    this.nombre,
    this.apellido,
    required this.rol,
    this.activo = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Nombre completo del usuario
  String get nombreCompleto {
    if (nombre != null && apellido != null) {
      return '$nombre $apellido';
    } else if (nombre != null) {
      return nombre!;
    } else if (apellido != null) {
      return apellido!;
    }
    return email;
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      email: json['email'] as String,
      nombre: json['nombre'] as String?,
      apellido: json['apellido'] as String?,
      rol: UserRole.fromString(json['rol'] as String? ?? 'usuario'),
      activo: json['activo'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombre': nombre,
        'apellido': apellido,
        'rol': rol.name,
        'activo': activo,
      };

  @override
  String toString() => '$nombreCompleto ($email) - ${rol.displayName}';
}
