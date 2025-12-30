import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/concepto_socio_model.dart';

final supabaseClient = Supabase.instance.client;

// Provider para obtener conceptos de un socio
final conceptosSocioProvider =
    FutureProvider.family<List<ConceptoSocio>, int>((ref, socioId) async {
  final response = await supabaseClient
      .from('conceptos_socios')
      .select('*')
      .eq('socio_id', socioId)
      .order('fecha_alta', ascending: false);

  return (response as List)
      .map((json) => ConceptoSocio.fromJson(json))
      .toList();
});

// Provider para obtener conceptos activos de un socio
final conceptosSocioActivosProvider =
    FutureProvider.family<List<ConceptoSocio>, int>((ref, socioId) async {
  final response = await supabaseClient
      .from('conceptos_socios')
      .select('*')
      .eq('socio_id', socioId)
      .isFilter('fecha_baja', null)
      .order('fecha_alta', ascending: false);

  return (response as List)
      .map((json) => ConceptoSocio.fromJson(json))
      .toList();
});

// Notifier para gestionar conceptos de socios
class ConceptosSocioNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  // Agregar concepto a un socio
  Future<void> agregarConcepto(ConceptoSocio concepto) async {
    state = const AsyncLoading();
    try {
      await supabaseClient.from('conceptos_socios').insert(concepto.toJson());
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  // Dar de baja un concepto
  Future<void> darDeBajaConcepto(int conceptoSocioId) async {
    state = const AsyncLoading();
    try {
      await supabaseClient.from('conceptos_socios').update({
        'fecha_baja': DateTime.now().toIso8601String(),
      }).eq('id', conceptoSocioId);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  // Actualizar concepto
  Future<void> actualizarConcepto(ConceptoSocio concepto) async {
    state = const AsyncLoading();
    try {
      await supabaseClient
          .from('conceptos_socios')
          .update(concepto.toJson())
          .eq('id', concepto.id!);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  // Eliminar concepto
  Future<void> eliminarConcepto(int conceptoSocioId) async {
    state = const AsyncLoading();
    try {
      await supabaseClient
          .from('conceptos_socios')
          .delete()
          .eq('id', conceptoSocioId);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }
}

final conceptosSocioNotifierProvider =
    NotifierProvider<ConceptosSocioNotifier, AsyncValue<void>>(
  ConceptosSocioNotifier.new,
);
