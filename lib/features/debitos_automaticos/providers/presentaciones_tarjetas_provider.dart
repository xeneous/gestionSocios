import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../services/historial_presentaciones_service.dart';
import '../models/presentacion_tarjeta.dart';

/// Provider del servicio de historial de presentaciones
final historialPresentacionesServiceProvider =
    Provider<HistorialPresentacionesService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return HistorialPresentacionesService(supabase);
});

/// Parámetros para el detalle de una presentación
class DetalleParams {
  final int tarjetaId;
  final int periodo;

  DetalleParams({required this.tarjetaId, required this.periodo});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetalleParams &&
          runtimeType == other.runtimeType &&
          tarjetaId == other.tarjetaId &&
          periodo == other.periodo;

  @override
  int get hashCode => tarjetaId.hashCode ^ periodo.hashCode;
}

/// Provider para listar presentaciones (filtradas opcionalmente por tarjeta)
/// El param es tarjetaId: null = todas, número = filtrada
final presentacionesTarjetasProvider =
    FutureProvider.family<List<PresentacionTarjeta>, int?>(
  (ref, tarjetaId) async {
    final service = ref.watch(historialPresentacionesServiceProvider);
    return service.getPresentaciones(tarjetaId: tarjetaId);
  },
);

/// Provider para el detalle de una presentación (por tarjeta + período)
final detallePresentacionProvider =
    FutureProvider.family<List<DetallePresentacion>, DetalleParams>(
  (ref, params) async {
    final service = ref.watch(historialPresentacionesServiceProvider);
    return service.getDetalle(params.tarjetaId, params.periodo);
  },
);
