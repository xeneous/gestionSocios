import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/parametro_contable_model.dart';
import '../services/parametros_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Provider del servicio de parámetros
final parametrosServiceProvider = Provider<ParametrosService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return ParametrosService(supabase);
});

/// Provider para obtener todos los parámetros
final parametrosProvider = FutureProvider<List<ParametroContable>>((ref) async {
  final service = ref.watch(parametrosServiceProvider);
  return service.getParametros();
});

/// Provider para obtener un parámetro específico
final parametroProvider = FutureProvider.family<ParametroContable?, String>((ref, clave) async {
  final service = ref.watch(parametrosServiceProvider);
  return service.getParametro(clave);
});

/// Provider para obtener cuentas de imputación
final cuentasImputacionProvider = FutureProvider<Map<String, int?>>((ref) async {
  final service = ref.watch(parametrosServiceProvider);
  return service.getCuentasImputacion();
});

/// Notifier para operaciones de parámetros
class ParametrosNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> actualizarParametro(String clave, String? valor) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(parametrosServiceProvider);
      await service.actualizarParametro(clave, valor);
      ref.invalidate(parametrosProvider);
      ref.invalidate(cuentasImputacionProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final parametrosNotifierProvider =
    NotifierProvider<ParametrosNotifier, AsyncValue<void>>(ParametrosNotifier.new);
