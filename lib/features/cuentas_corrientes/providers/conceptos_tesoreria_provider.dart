import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/concepto_tesoreria_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider para obtener todos los conceptos de tesorería
final conceptosTesoreriaProvider = FutureProvider<List<ConceptoTesoreria>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('conceptos_tesoreria')
      .select()
      .order('descripcion', ascending: true);

  return (response as List)
      .map((json) => ConceptoTesoreria.fromJson(json))
      .toList();
});

/// Provider para obtener conceptos de cartera de ingreso (para cobros)
/// Filtra por ci='S' y activo=true
final conceptosCarteraIngresoProvider = FutureProvider<List<ConceptoTesoreria>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('conceptos_tesoreria')
      .select()
      .eq('ci', 'S')
      .eq('activo', true)
      .order('descripcion', ascending: true);

  return (response as List)
      .map((json) => ConceptoTesoreria.fromJson(json))
      .toList();
});

/// Provider para obtener conceptos de cartera de egreso (para pagos)
final conceptosCarteraEgresoProvider = FutureProvider<List<ConceptoTesoreria>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('conceptos_tesoreria')
      .select()
      .eq('ce', 'S')
      .order('descripcion', ascending: true);

  return (response as List)
      .map((json) => ConceptoTesoreria.fromJson(json))
      .toList();
});

/// Provider para obtener un concepto por ID
final conceptoTesoreriaByIdProvider =
    FutureProvider.family<ConceptoTesoreria?, int>((ref, id) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('conceptos_tesoreria')
      .select()
      .eq('id', id)
      .maybeSingle();

  if (response == null) return null;
  return ConceptoTesoreria.fromJson(response);
});

// ============================================================================
// NOTIFIER PARA CRUD
// ============================================================================

class ConceptosTesoreriaNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  /// Crear nuevo concepto de tesorería
  Future<void> createConcepto(ConceptoTesoreria concepto) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase
          .from('conceptos_tesoreria')
          .insert(concepto.toJson());

      // Invalidar cache
      ref.invalidate(conceptosTesoreriaProvider);
      ref.invalidate(conceptosCarteraIngresoProvider);
      ref.invalidate(conceptosCarteraEgresoProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Actualizar concepto existente
  Future<void> updateConcepto(int id, ConceptoTesoreria concepto) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase
          .from('conceptos_tesoreria')
          .update(concepto.toJson())
          .eq('id', id);

      // Invalidar cache
      ref.invalidate(conceptosTesoreriaProvider);
      ref.invalidate(conceptosCarteraIngresoProvider);
      ref.invalidate(conceptosCarteraEgresoProvider);
      ref.invalidate(conceptoTesoreriaByIdProvider(id));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Eliminar concepto
  Future<void> deleteConcepto(int id) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase
          .from('conceptos_tesoreria')
          .delete()
          .eq('id', id);

      // Invalidar cache
      ref.invalidate(conceptosTesoreriaProvider);
      ref.invalidate(conceptosCarteraIngresoProvider);
      ref.invalidate(conceptosCarteraEgresoProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Activar/Desactivar concepto
  Future<void> toggleActivo(int id, bool activo) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase
          .from('conceptos_tesoreria')
          .update({'activo': activo})
          .eq('id', id);

      // Invalidar cache
      ref.invalidate(conceptosTesoreriaProvider);
      ref.invalidate(conceptosCarteraIngresoProvider);
      ref.invalidate(conceptosCarteraEgresoProvider);
      ref.invalidate(conceptoTesoreriaByIdProvider(id));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final conceptosTesoreriaNotifierProvider =
    NotifierProvider<ConceptosTesoreriaNotifier, AsyncValue<void>>(() {
  return ConceptosTesoreriaNotifier();
});
