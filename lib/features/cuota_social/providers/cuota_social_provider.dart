import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cuota_social_service.dart';
import '../models/valor_cuota_social_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Provider del servicio de cuota social
final cuotaSocialServiceProvider = Provider<CuotaSocialService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return CuotaSocialService(supabase);
});

/// Provider para obtener valores de cuota configurados
final valoresCuotaProvider = FutureProvider<List<ValorCuotaSocial>>((ref) async {
  final service = ref.watch(cuotaSocialServiceProvider);
  return service.getValoresCuota();
});

/// Provider para generar items de cuota (usado en el diálogo)
final itemsCuotaProvider = FutureProvider.family<List<CuotaSocialItem>, ItemsCuotaParams>(
  (ref, params) async {
    final service = ref.watch(cuotaSocialServiceProvider);
    return service.generarItemsCuota(
      esResidente: params.esResidente,
      cantidadMeses: params.cantidadMeses,
      fechaInicio: params.fechaInicio,
    );
  },
);

/// Parámetros para generar items de cuota
class ItemsCuotaParams {
  final bool esResidente;
  final int cantidadMeses;
  final DateTime? fechaInicio;

  ItemsCuotaParams({
    required this.esResidente,
    this.cantidadMeses = 3,
    this.fechaInicio,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemsCuotaParams &&
          runtimeType == other.runtimeType &&
          esResidente == other.esResidente &&
          cantidadMeses == other.cantidadMeses &&
          fechaInicio == other.fechaInicio;

  @override
  int get hashCode =>
      esResidente.hashCode ^ cantidadMeses.hashCode ^ fechaInicio.hashCode;
}

/// Notifier para manejar el CRUD de valores de cuota social
class ValoresCuotaNotifier extends Notifier<AsyncValue<List<ValorCuotaSocial>>> {
  @override
  AsyncValue<List<ValorCuotaSocial>> build() {
    // Cargar valores inicialmente
    _loadValores();
    return const AsyncValue.loading();
  }

  Future<void> _loadValores() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(cuotaSocialServiceProvider);
      final valores = await service.getValoresCuota();
      state = AsyncValue.data(valores);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresca la lista de valores
  Future<void> refresh() => _loadValores();

  /// Crea un nuevo valor de cuota
  Future<void> crear({
    required int anioMesInicio,
    required int? anioMesCierre,
    required double valorResidente,
    required double valorTitular,
  }) async {
    try {
      final service = ref.read(cuotaSocialServiceProvider);
      await service.crearValorCuota(
        anioMesInicio: anioMesInicio,
        anioMesCierre: anioMesCierre,
        valorResidente: valorResidente,
        valorTitular: valorTitular,
      );
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  /// Actualiza un valor de cuota existente
  Future<void> actualizar({
    required int id,
    required int anioMesInicio,
    required int? anioMesCierre,
    required double valorResidente,
    required double valorTitular,
  }) async {
    try {
      final service = ref.read(cuotaSocialServiceProvider);
      await service.actualizarValorCuota(
        id: id,
        anioMesInicio: anioMesInicio,
        anioMesCierre: anioMesCierre,
        valorResidente: valorResidente,
        valorTitular: valorTitular,
      );
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  /// Elimina un valor de cuota
  Future<void> eliminar(int id) async {
    try {
      final service = ref.read(cuotaSocialServiceProvider);
      await service.eliminarValorCuota(id);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}

/// Provider del notifier de valores de cuota
final valoresCuotaNotifierProvider =
    NotifierProvider<ValoresCuotaNotifier, AsyncValue<List<ValorCuotaSocial>>>(
  () => ValoresCuotaNotifier(),
);
