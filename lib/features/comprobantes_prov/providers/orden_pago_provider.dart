import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/orden_pago_service.dart';
import '../../asientos/services/asientos_service.dart';
import '../../asientos/providers/asientos_provider.dart';
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

  /// Genera una nueva orden de pago con su asiento contable
  /// Retorna un map con 'numero_orden_pago' y 'numero_asiento'
  Future<Map<String, int>> generarOrdenPago({
    required int proveedorId,
    required Map<int, double> transaccionesAPagar,
    required Map<int, double> formasPago,
    int? operadorId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final ordenPagoService = ref.read(ordenPagoServiceProvider);
      final asientosService = ref.read(asientosServiceProvider);
      final supabase = ref.read(supabaseProvider);

      // 0. Obtener nombre del proveedor para el detalle del asiento
      final proveedorData = await supabase
          .from('proveedores')
          .select('razon_social')
          .eq('codigo', proveedorId)
          .single();

      final nombreCompleto = (proveedorData['razon_social'] as String?)?.trim() ?? 'Proveedor $proveedorId';

      // 1. Generar la orden de pago
      final resultado = await ordenPagoService.generarOrdenPago(
        proveedorId: proveedorId,
        transaccionesAPagar: transaccionesAPagar,
        formasPago: formasPago,
        operadorId: operadorId,
      );

      final numeroOP = resultado['numero_orden_pago'] as int;

      // 2. Preparar items del asiento de diario
      // Para orden de pago a proveedores:
      // DEBE: Proveedores (disminuye lo que debemos)
      // HABER: Caja/Banco (disminuye nuestro efectivo)
      final itemsAsiento = <AsientoItemData>[];

      // 2.1. DEBE - Cuenta de proveedores
      for (final transaccion in transaccionesAPagar.entries) {
        // Obtener datos de la transacción
        final transaccionData = await supabase
            .from('comp_prov_header')
            .select('tipo_comprobante, nro_comprobante')
            .eq('id_transaccion', transaccion.key)
            .single();

        final tipoComprobante = transaccionData['tipo_comprobante'] as int;
        final nroComprobante = transaccionData['nro_comprobante'] as String?;

        // Obtener items de la transacción con cuenta contable
        final detalles = await supabase
            .from('comp_prov_items')
            .select('importe, cuenta')
            .eq('id_transaccion', transaccion.key);

        if (detalles.isEmpty) {
          // Si no hay items, usar cuenta genérica de proveedores
          itemsAsiento.add(AsientoItemData(
            cuentaId: 21110100, // Cuenta genérica proveedores - ajustar
            debe: transaccion.value,
            haber: 0,
            observacion: 'OP Nro. $numeroOP - Tipo $tipoComprobante ${nroComprobante ?? ''}',
          ));
        } else {
          // Calcular total de items para prorrateo
          final totalItems = detalles.fold<double>(
            0, (sum, d) => sum + ((d['importe'] as num).toDouble()).abs());

          // Crear items DEBE proporcionales
          for (final detalle in detalles) {
            final importeDetalle = ((detalle['importe'] as num).toDouble()).abs();
            final numeroCuentaContable = detalle['cuenta'] as int? ?? 21110100;

            // Calcular monto proporcional
            final montoProporcional = totalItems > 0
                ? (transaccion.value / totalItems) * importeDetalle
                : 0.0;

            itemsAsiento.add(AsientoItemData(
              cuentaId: numeroCuentaContable,
              debe: montoProporcional,
              haber: 0,
              observacion: 'OP Nro. $numeroOP - Tipo $tipoComprobante ${nroComprobante ?? ''}',
            ));
          }
        }
      }

      // 2.2. HABER - Cuentas de caja/banco (desde formas de pago)
      for (final formaPago in formasPago.entries) {
        // Obtener cuenta contable desde conceptos_tesoreria
        final conceptoTesoreria = await supabase
            .from('conceptos_tesoreria')
            .select('imputacion_contable')
            .eq('id', formaPago.key)
            .single();

        final imputacionContable = conceptoTesoreria['imputacion_contable'] as String?;

        if (imputacionContable == null || imputacionContable.isEmpty) {
          throw Exception('Concepto de tesorería ${formaPago.key} no tiene imputación contable configurada');
        }

        final numeroCuenta = int.parse(imputacionContable);

        itemsAsiento.add(AsientoItemData(
          cuentaId: numeroCuenta,
          debe: 0,
          haber: formaPago.value,
          observacion: 'OP Nro. $numeroOP',
        ));
      }

      // 3. Generar asiento usando AsientosService
      final numeroAsiento = await asientosService.crearAsiento(
        tipoAsiento: AsientosService.tipoEgreso, // Tipo 2 = Egreso
        fecha: DateTime.now(),
        detalle: 'OP Nro. $numeroOP - $nombreCompleto',
        items: itemsAsiento,
        numeroComprobante: numeroOP,
        nombrePersona: nombreCompleto,
      );

      state = const AsyncValue.data(null);

      return {
        'numero_orden_pago': numeroOP,
        'numero_asiento': numeroAsiento,
      };
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
