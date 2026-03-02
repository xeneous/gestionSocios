import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/user_role.dart';
import 'usuarios_provider.dart';

/// Provider del rol del usuario actual
/// Lee el rol desde la tabla usuarios
final userRoleProvider = Provider<UserRole>((ref) {
  final userProfile = ref.watch(currentUserProfileProvider);

  // Si no hay perfil cargado o hay error, retornar usuario básico
  final result = userProfile.when(
    data: (usuario) {
      return usuario?.rol ?? UserRole.usuario;
    },
    loading: () {
      return UserRole.usuario;
    },
    error: (e, st) {
      return UserRole.usuario;
    },
  );

  return result;
});
