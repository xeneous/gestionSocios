import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recertificacion_model.dart';

final supabaseClient = Supabase.instance.client;

// Provider para obtener recertificaciones de un socio
final recertificacionesSocioProvider =
    FutureProvider.family<List<RecertificacionModel>, int>((ref, socioId) async {
  final response = await supabaseClient
      .from('recertificaciones_socios')
      .select('*')
      .eq('socio_id', socioId)
      .order('fecha_recertificacion', ascending: false);

  return (response as List)
      .map((json) => RecertificacionModel.fromJson(json))
      .toList();
});

// Notifier para gestionar recertificaciones de socios
class RecertificacionesNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  // Agregar recertificación
  Future<void> agregarRecertificacion(RecertificacionModel recertificacion) async {
    state = const AsyncLoading();
    try {
      await supabaseClient
          .from('recertificaciones_socios')
          .insert(recertificacion.toJson());
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  // Actualizar recertificación
  Future<void> actualizarRecertificacion(RecertificacionModel recertificacion) async {
    state = const AsyncLoading();
    try {
      await supabaseClient
          .from('recertificaciones_socios')
          .update(recertificacion.toJson())
          .eq('id', recertificacion.id!);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  // Eliminar recertificación
  Future<void> eliminarRecertificacion(int recertificacionId) async {
    state = const AsyncLoading();
    try {
      await supabaseClient
          .from('recertificaciones_socios')
          .delete()
          .eq('id', recertificacionId);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }
}

final recertificacionesNotifierProvider =
    NotifierProvider<RecertificacionesNotifier, AsyncValue<void>>(
  RecertificacionesNotifier.new,
);
