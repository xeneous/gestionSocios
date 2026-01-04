/// Roles de usuario en el sistema
enum UserRole {
  usuario('Usuario'),
  contable('Contable'),
  supervisor('Supervisor'),
  administrador('Administrador');

  final String displayName;
  const UserRole(this.displayName);

  /// Convierte string a enum
  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'administrador':
        return UserRole.administrador;
      case 'supervisor':
        return UserRole.supervisor;
      case 'contable':
        return UserRole.contable;
      case 'usuario':
      default:
        return UserRole.usuario;
    }
  }

  /// Verifica si el rol tiene permisos de administrador
  bool get esAdministrador => this == UserRole.administrador;

  /// Verifica si el rol tiene permisos de supervisor o superior
  bool get esSupervisorOMayor =>
      this == UserRole.supervisor || this == UserRole.administrador;

  /// Verifica si el rol tiene permisos de contable o superior
  bool get esContableOMayor =>
      this == UserRole.contable ||
      this == UserRole.supervisor ||
      this == UserRole.administrador;

  /// Verifica si puede acceder a mantenimiento
  bool get puedeAccederMantenimiento => esAdministrador;

  /// Verifica si puede facturar cuotas masivamente
  bool get puedeFacturarMasivo => esSupervisorOMayor;
}
