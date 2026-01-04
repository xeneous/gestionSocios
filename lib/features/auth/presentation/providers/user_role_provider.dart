import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/user_role.dart';
import 'usuarios_provider.dart';

/// Provider del rol del usuario actual
/// Lee el rol desde la tabla usuarios
final userRoleProvider = Provider<UserRole>((ref) {
  final userProfile = ref.watch(currentUserProfileProvider);

  print('🎯 DEBUG userRoleProvider:');
  print('  - userProfile state: ${userProfile.runtimeType}');

  // Si no hay perfil cargado o hay error, retornar usuario básico
  final result = userProfile.when(
    data: (usuario) {
      print('  - data: usuario=${usuario?.email}, rol=${usuario?.rol.name}');
      return usuario?.rol ?? UserRole.usuario;
    },
    loading: () {
      print('  - loading: returning UserRole.usuario');
      return UserRole.usuario;
    },
    error: (e, st) {
      print('  - error: $e, returning UserRole.usuario');
      return UserRole.usuario;
    },
  );

  print('  - FINAL RESULT: ${result.name}');
  return result;
});
