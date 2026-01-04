import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../services/facturador_service.dart';
import '../models/facturacion_previa_model.dart';

/// Provider del servicio de facturador
final facturadorServiceProvider = Provider<FacturadorService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return FacturadorService(supabase);
});

/// Provider para la vista previa de facturación
final vistaPreviaFacturacionProvider = FutureProvider.family<
    ResumenFacturacion,
    List<PeriodoFacturacion>>((ref, periodos) async {
  final service = ref.read(facturadorServiceProvider);
  return service.obtenerVistaPrevia(periodos: periodos);
});

/// Progreso de la generación (0.0 a 1.0)
class ProgresoGeneracion {
  final int actual;
  final int total;

  ProgresoGeneracion(this.actual, this.total);

  double get porcentaje => total > 0 ? actual / total : 0.0;
}

/// Stream provider para el progreso
final progresoGeneracionProvider = StreamProvider<ProgresoGeneracion>((ref) {
  final controller = StreamController<ProgresoGeneracion>();
  ref.onDispose(() => controller.close());

  // Inicialmente sin progreso
  controller.add(ProgresoGeneracion(0, 0));

  return controller.stream;
});

/// Notifier para el proceso de facturación
class FacturadorNotifier extends Notifier<AsyncValue<void>> {
  StreamController<ProgresoGeneracion>? _progresoController;

  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  /// Genera cuotas masivamente
  Future<void> generarCuotas(
    ResumenFacturacion resumen,
    StreamController<ProgresoGeneracion> progresoController,
  ) async {
    _progresoController = progresoController;
    state = const AsyncValue.loading();

    // Reset progreso
    _progresoController?.add(ProgresoGeneracion(0, resumen.totalCuotas));

    try {
      final service = ref.read(facturadorServiceProvider);

      await service.generarCuotasMasivas(
        resumen: resumen,
        onProgress: (current, total) {
          // Enviar progreso por el stream
          _progresoController?.add(ProgresoGeneracion(current, total));
        },
      );

      _progresoController?.add(ProgresoGeneracion(resumen.totalCuotas, resumen.totalCuotas));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      _progresoController?.add(ProgresoGeneracion(0, 0));
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      _progresoController = null;
    }
  }

  /// Resetea el estado
  void reset() {
    _progresoController?.add(ProgresoGeneracion(0, 0));
    _progresoController = null;
    state = const AsyncValue.data(null);
  }
}

final facturadorNotifierProvider =
    NotifierProvider<FacturadorNotifier, AsyncValue<void>>(() {
  return FacturadorNotifier();
});
