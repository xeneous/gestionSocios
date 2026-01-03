import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/valor_tesoreria_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider para obtener todos los valores de tesorería
final valoresTesoreriaProvider = FutureProvider<List<ValorTesoreria>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('valores_tesoreria')
      .select()
      .order('id', ascending: false);

  return (response as List)
      .map((json) => ValorTesoreria.fromJson(json))
      .toList();
});

/// Provider para obtener valores por idtransaccion_origen
final valoresByTransaccionOrigenProvider =
    FutureProvider.family<List<ValorTesoreria>, int>((ref, idTransaccionOrigen) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('valores_tesoreria')
      .select()
      .eq('idtransaccion_origen', idTransaccionOrigen)
      .order('id', ascending: false);

  return (response as List)
      .map((json) => ValorTesoreria.fromJson(json))
      .toList();
});

/// Provider para obtener valores pendientes (no cancelados completamente)
final valoresPendientesProvider = FutureProvider<List<ValorTesoreria>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('valores_tesoreria')
      .select()
      .filter('importe', 'gt', 'cancelado')
      .order('vencimiento', ascending: true);

  return (response as List)
      .map((json) => ValorTesoreria.fromJson(json))
      .toList();
});

/// Provider para obtener un valor por ID
final valorTesoreriaByIdProvider =
    FutureProvider.family<ValorTesoreria?, int>((ref, id) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('valores_tesoreria')
      .select()
      .eq('id', id)
      .maybeSingle();

  if (response == null) return null;
  return ValorTesoreria.fromJson(response);
});
