import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/observacion_socio_model.dart';

final supabaseClient = Supabase.instance.client;

// Provider para obtener observaciones de un socio
final observacionesSocioProvider =
    FutureProvider.family<List<ObservacionSocio>, int>((ref, socioId) async {
  final response = await supabaseClient
      .from('observaciones_socios')
      .select('*')
      .eq('socio_id', socioId)
      .order('fecha', ascending: false);

  return (response as List)
      .map((json) => ObservacionSocio.fromJson(json))
      .toList();
});

// Notifier para gestionar observaciones de socios
class ObservacionesSocioNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  // Agregar observación
  Future<void> agregarObservacion(ObservacionSocio observacion) async {
    state = const AsyncLoading();
    try {
      await supabaseClient
          .from('observaciones_socios')
          .insert(observacion.toJson());
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  // Actualizar observación
  Future<void> actualizarObservacion(ObservacionSocio observacion) async {
    state = const AsyncLoading();
    try {
      await supabaseClient
          .from('observaciones_socios')
          .update(observacion.toJson())
          .eq('id', observacion.id!);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  // Eliminar observación
  Future<void> eliminarObservacion(int observacionId) async {
    state = const AsyncLoading();
    try {
      await supabaseClient
          .from('observaciones_socios')
          .delete()
          .eq('id', observacionId);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }
}

final observacionesSocioNotifierProvider =
    NotifierProvider<ObservacionesSocioNotifier, AsyncValue<void>>(
  ObservacionesSocioNotifier.new,
);
