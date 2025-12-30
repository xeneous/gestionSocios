import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth state stream provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange;
});

// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user;
});

// Auth actions notifier using Riverpod 3.0 API
class AuthNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }
  
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.auth.signUp(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(() {
  return AuthNotifier();
});
