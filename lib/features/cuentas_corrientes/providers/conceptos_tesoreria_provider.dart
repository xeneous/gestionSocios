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
final conceptosCarteraIngresoProvider = FutureProvider<List<ConceptoTesoreria>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('conceptos_tesoreria')
      .select()
      .eq('ci', 'S')
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
