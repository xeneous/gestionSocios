import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cobranzas_clientes_service.dart';
import '../../asientos/services/asientos_service.dart';
import '../../asientos/providers/asientos_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider del servicio de cobranzas de clientes
final cobranzasClientesServiceProvider = Provider<CobranzasClientesService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return CobranzasClientesService(supabase);
});

/// Provider para obtener comprobantes pendientes de un cliente
final comprobantesPendientesClienteProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, clienteId) async {
  final service = ref.watch(cobranzasClientesServiceProvider);
  return service.getComprobantesPendientes(clienteId);
});

/// Provider para obtener saldo de un cliente
final saldoClienteProvider = FutureProvider.family<Map<String, double>, int>((ref, clienteId) async {
  final service = ref.watch(cobranzasClientesServiceProvider);
  return service.getSaldoCliente(clienteId);
});

/// Notifier para manejar operaciones de cobranzas de clientes
class CobranzasClientesNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  /// Genera un nuevo recibo de cobranza con su asiento contable
  /// Retorna un map con 'numero_recibo' y 'numero_asiento'
  Future<Map<String, int>> generarRecibo({
    required int clienteId,
    required Map<int, double> transaccionesAPagar,
    required Map<int, double> formasPago,
    int? operadorId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final cobranzasService = ref.read(cobranzasClientesServiceProvider);
      final asientosService = ref.read(asientosServiceProvider);
      final supabase = ref.read(supabaseProvider);

      // 0. Obtener nombre del cliente para el detalle del asiento
      final clienteData = await supabase
          .from('clientes')
          .select('razon_social')
          .eq('codigo', clienteId)
          .single();

      final nombreCompleto = (clienteData['razon_social'] as String?)?.trim() ?? 'Cliente $clienteId';

      // 1. Generar el recibo
      final resultado = await cobranzasService.generarRecibo(
        clienteId: clienteId,
        transaccionesAPagar: transaccionesAPagar,
        formasPago: formasPago,
        operadorId: operadorId,
      );

      final numeroRecibo = resultado['numero_recibo'] as int;

      // 2. Preparar items del asiento de diario
      final itemsAsiento = <AsientoItemData>[];

      // 2.1. DEBE - Cuentas de caja/banco (desde formas de pago)
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
          debe: formaPago.value,
          haber: 0,
          observacion: 'Recibo Cli Nro. $numeroRecibo',
        ));
      }

      // 2.2. HABER - Cuenta de deudores por ventas (clientes)
      // Obtener la cuenta contable de deudores desde la primera transacción pagada
      for (final transaccion in transaccionesAPagar.entries) {
        // Obtener datos de la transacción
        final transaccionData = await supabase
            .from('ven_cli_header')
            .select('tipo_comprobante, nro_comprobante')
            .eq('id_transaccion', transaccion.key)
            .single();

        final tipoComprobante = transaccionData['tipo_comprobante'] as int;
        final nroComprobante = transaccionData['nro_comprobante'] as String?;

        // Obtener items de la transacción con cuenta contable
        final detalles = await supabase
            .from('ven_cli_items')
            .select('importe, cuenta')
            .eq('id_transaccion', transaccion.key);

        if (detalles.isEmpty) {
          // Si no hay items, usar cuenta genérica de deudores (ajustar según plan de cuentas)
          itemsAsiento.add(AsientoItemData(
            cuentaId: 11310100, // Cuenta genérica deudores - ajustar
            debe: 0,
            haber: transaccion.value,
            observacion: 'Recibo Cli Nro. $numeroRecibo - Tipo $tipoComprobante ${nroComprobante ?? ''}',
          ));
        } else {
          // Calcular total de items para prorrateo
          final totalItems = detalles.fold<double>(
            0, (sum, d) => sum + ((d['importe'] as num).toDouble()).abs());

          // Crear items HABER proporcionales
          for (final detalle in detalles) {
            final importeDetalle = ((detalle['importe'] as num).toDouble()).abs();
            final numeroCuentaContable = detalle['cuenta'] as int? ?? 11310100;

            // Calcular monto proporcional
            final montoProporcional = totalItems > 0
                ? (transaccion.value / totalItems) * importeDetalle
                : 0.0;

            itemsAsiento.add(AsientoItemData(
              cuentaId: numeroCuentaContable,
              debe: 0,
              haber: montoProporcional,
              observacion: 'Recibo Cli Nro. $numeroRecibo - Tipo $tipoComprobante ${nroComprobante ?? ''}',
            ));
          }
        }
      }

      // 3. Generar asiento usando AsientosService
      final numeroAsiento = await asientosService.crearAsiento(
        tipoAsiento: AsientosService.tipoIngreso, // Tipo 1 = Ingreso
        fecha: DateTime.now(),
        detalle: 'Recibo Cli Nro. $numeroRecibo - $nombreCompleto',
        items: itemsAsiento,
        numeroComprobante: numeroRecibo,
        nombrePersona: nombreCompleto,
      );

      state = const AsyncValue.data(null);

      return {
        'numero_recibo': numeroRecibo,
        'numero_asiento': numeroAsiento,
      };
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Provider del notifier de cobranzas de clientes
final cobranzasClientesNotifierProvider =
    NotifierProvider<CobranzasClientesNotifier, AsyncValue<void>>(() {
  return CobranzasClientesNotifier();
});
