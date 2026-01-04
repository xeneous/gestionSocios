import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/concepto_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Provider para obtener todos los conceptos
final conceptosProvider = FutureProvider<List<Concepto>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('conceptos')
      .select()
      .order('concepto', ascending: true);

  return (response as List)
      .map((json) => Concepto.fromJson(json))
      .toList();
});

/// Provider para obtener conceptos activos (para formularios)
final conceptosActivosProvider = FutureProvider<List<Concepto>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('conceptos')
      .select()
      .eq('activo', true)
      .order('concepto', ascending: true);

  return (response as List)
      .map((json) => Concepto.fromJson(json))
      .toList();
});

/// Provider para obtener un concepto por código
final conceptoByCodigoProvider =
    FutureProvider.family<Concepto?, String>((ref, concepto) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('conceptos')
      .select()
      .eq('concepto', concepto)
      .maybeSingle();

  if (response == null) return null;
  return Concepto.fromJson(response);
});

// ============================================================================
// NOTIFIER PARA CRUD
// ============================================================================

class ConceptosNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  /// Crear nuevo concepto
  Future<void> createConcepto(Concepto concepto) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase
          .from('conceptos')
          .insert(concepto.toJson());

      // Invalidar cache
      ref.invalidate(conceptosProvider);
      ref.invalidate(conceptosActivosProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Actualizar concepto existente
  Future<void> updateConcepto(String codigo, Concepto concepto) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase
          .from('conceptos')
          .update(concepto.toJson())
          .eq('concepto', codigo);

      // Invalidar cache
      ref.invalidate(conceptosProvider);
      ref.invalidate(conceptosActivosProvider);
      ref.invalidate(conceptoByCodigoProvider(codigo));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Eliminar concepto
  Future<void> deleteConcepto(String codigo) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase
          .from('conceptos')
          .delete()
          .eq('concepto', codigo);

      // Invalidar cache
      ref.invalidate(conceptosProvider);
      ref.invalidate(conceptosActivosProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Activar/Desactivar concepto
  Future<void> toggleActivo(String codigo, bool activo) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase
          .from('conceptos')
          .update({'activo': activo})
          .eq('concepto', codigo);

      // Invalidar cache
      ref.invalidate(conceptosProvider);
      ref.invalidate(conceptosActivosProvider);
      ref.invalidate(conceptoByCodigoProvider(codigo));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final conceptosNotifierProvider =
    NotifierProvider<ConceptosNotifier, AsyncValue<void>>(() {
  return ConceptosNotifier();
});
