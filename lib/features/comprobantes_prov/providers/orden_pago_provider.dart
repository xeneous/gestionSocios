import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/orden_pago_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider del servicio de orden de pago
final ordenPagoServiceProvider = Provider<OrdenPagoService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return OrdenPagoService(supabase);
});

/// Provider para obtener comprobantes pendientes de pago de un proveedor
final comprobantesPendientesProveedorProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, proveedorId) async {
  final service = ref.watch(ordenPagoServiceProvider);
  return service.getComprobantesPendientes(proveedorId);
});

/// Provider para obtener saldo de un proveedor
final saldoProveedorProvider = FutureProvider.family<Map<String, double>, int>((ref, proveedorId) async {
  final service = ref.watch(ordenPagoServiceProvider);
  return service.getSaldoProveedor(proveedorId);
});

/// Notifier para manejar operaciones de orden de pago
class OrdenPagoNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  /// Genera una nueva orden de pago con su asiento contable.
  /// Delega toda la lógica al [OrdenPagoService].
  /// Retorna el map del servicio con 'numero_orden_pago', 'id_transaccion',
  /// 'numero_asiento' (null si falló) y 'asiento_error' (null si ok).
  Future<Map<String, dynamic>> generarOrdenPago({
    required int proveedorId,
    required Map<int, double> transaccionesAPagar,
    required Map<int, double> formasPago,
    int? operadorId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final ordenPagoService = ref.read(ordenPagoServiceProvider);
      final resultado = await ordenPagoService.generarOrdenPago(
        proveedorId: proveedorId,
        transaccionesAPagar: transaccionesAPagar,
        formasPago: formasPago,
        operadorId: operadorId,
      );
      state = const AsyncValue.data(null);
      return resultado;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Provider del notifier de orden de pago
final ordenPagoNotifierProvider =
    NotifierProvider<OrdenPagoNotifier, AsyncValue<void>>(() {
  return OrdenPagoNotifier();
});
