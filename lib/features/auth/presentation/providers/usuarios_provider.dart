import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/user_role.dart';
import '../../models/usuario_model.dart';
import 'auth_provider.dart';

/// Provider para obtener todos los usuarios
final usuariosProvider = FutureProvider<List<Usuario>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('usuarios')
      .select()
      .order('created_at', ascending: false);

  return (response as List)
      .map((json) => Usuario.fromJson(json))
      .toList();
});

/// Provider para obtener un usuario por ID
final usuarioByIdProvider =
    FutureProvider.family<Usuario?, String>((ref, userId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('usuarios')
      .select()
      .eq('id', userId)
      .maybeSingle();

  if (response == null) return null;
  return Usuario.fromJson(response);
});

/// Provider para obtener el perfil del usuario actual
final currentUserProfileProvider = FutureProvider<Usuario?>((ref) async {
  final user = ref.watch(currentUserProvider);

  print('🔍 DEBUG currentUserProfileProvider:');
  print('  - user: ${user?.email} (id: ${user?.id})');

  if (user == null) {
    print('  - Result: null (no user)');
    return null;
  }

  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('usuarios')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  print('  - DB response: $response');

  if (response == null) {
    print('  - Result: null (no DB record)');
    return null;
  }

  final usuario = Usuario.fromJson(response);
  print('  - Parsed usuario: ${usuario.email}, rol: ${usuario.rol.name}');

  return usuario;
});

// ============================================================================
// NOTIFIER PARA CRUD DE USUARIOS
// ============================================================================

class UsuariosNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  /// Crear nuevo usuario (solo admins)
  /// Nota: Esto crea el usuario en auth.users, y el trigger creará el registro en usuarios
  Future<void> createUsuario({
    required String email,
    required String password,
    String? nombre,
    String? apellido,
    required UserRole rol,
  }) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      // Crear usuario en auth (solo admins pueden hacer esto via Admin API)
      // Nota: Esto requiere service_role key, por ahora usamos el método normal
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Error al crear usuario');
      }

      // El trigger handle_new_user() ya creó el registro en usuarios
      // Ahora actualizamos el rol y otros datos
      await supabase.from('usuarios').update({
        'nombre': nombre,
        'apellido': apellido,
        'rol': rol.name,
      }).eq('id', response.user!.id);

      // Invalidar cache
      ref.invalidate(usuariosProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Actualizar usuario (admins pueden actualizar cualquiera)
  Future<void> updateUsuario(String userId, {
    String? nombre,
    String? apellido,
    UserRole? rol,
    bool? activo,
  }) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      final updates = <String, dynamic>{};
      if (nombre != null) updates['nombre'] = nombre;
      if (apellido != null) updates['apellido'] = apellido;
      if (rol != null) updates['rol'] = rol.name;
      if (activo != null) updates['activo'] = activo;

      await supabase
          .from('usuarios')
          .update(updates)
          .eq('id', userId);

      // Invalidar cache
      ref.invalidate(usuariosProvider);
      ref.invalidate(usuarioByIdProvider(userId));
      ref.invalidate(currentUserProfileProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Cambiar contraseña del usuario actual
  Future<void> changePassword(String newPassword) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Eliminar usuario (solo admins)
  /// Nota: Al eliminar de auth.users, el CASCADE eliminará de usuarios
  Future<void> deleteUsuario(String userId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      // Nota: Esto requiere service_role key para funcionar correctamente
      // Por ahora solo desactivamos el usuario
      await supabase
          .from('usuarios')
          .update({'activo': false})
          .eq('id', userId);

      // Invalidar cache
      ref.invalidate(usuariosProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Activar/Desactivar usuario
  Future<void> toggleActivo(String userId, bool activo) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase
          .from('usuarios')
          .update({'activo': activo})
          .eq('id', userId);

      // Invalidar cache
      ref.invalidate(usuariosProvider);
      ref.invalidate(usuarioByIdProvider(userId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final usuariosNotifierProvider =
    NotifierProvider<UsuariosNotifier, AsyncValue<void>>(() {
  return UsuariosNotifier();
});
