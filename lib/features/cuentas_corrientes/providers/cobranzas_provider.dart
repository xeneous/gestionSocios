import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cobranzas_service.dart';
import '../services/recibo_pdf_service.dart';
import '../../asientos/services/asientos_service.dart';
import '../../asientos/providers/asientos_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider del servicio de cobranzas
final cobranzasServiceProvider = Provider<CobranzasService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return CobranzasService(supabase);
});

/// Provider del servicio de generación de PDFs de recibos
final reciboPdfServiceProvider = Provider<ReciboPdfService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return ReciboPdfService(supabase);
});

/// Notifier para manejar operaciones de cobranzas
class CobranzasNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  /// Genera un nuevo recibo de cobranza con su asiento contable
  /// Retorna un map con 'numero_recibo' y 'numero_asiento'
  Future<Map<String, int>> generarRecibo({
    int? socioId,
    int? profesionalId,
    required Map<int, double> transaccionesAPagar,
    required Map<int, double> formasPago,
    int? operadorId,
    int? numeroRecibo,
  }) async {
    assert(socioId != null || profesionalId != null,
        'Debe proveer socioId o profesionalId');

    state = const AsyncValue.loading();

    try {
      final cobranzasService = ref.read(cobranzasServiceProvider);
      final asientosService = ref.read(asientosServiceProvider);
      final supabase = ref.read(supabaseProvider);

      // 0. Obtener nombre de la entidad para el detalle del asiento
      String nombreCompleto;
      if (profesionalId != null) {
        final data = await supabase
            .from('profesionales')
            .select('apellido, nombre')
            .eq('id', profesionalId)
            .single();
        nombreCompleto = '${data['apellido']}, ${data['nombre']}'.trim();
      } else {
        final data = await supabase
            .from('socios')
            .select('apellido, nombre')
            .eq('id', socioId!)
            .single();
        nombreCompleto = '${data['apellido']}, ${data['nombre']}'.trim();
      }

      // 1. Generar el recibo (PostgreSQL)
      final nroRecibo = await cobranzasService.generarRecibo(
        socioId: socioId,
        profesionalId: profesionalId,
        transaccionesAPagar: transaccionesAPagar,
        formasPago: formasPago,
        operadorId: operadorId,
        numeroRecibo: numeroRecibo,
      );

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

        // El cuentaId es el NÚMERO de cuenta, no un ID de tabla
        // Esto es consistente con el alta de asientos manual (asiento_form_page.dart:181)
        final numeroCuenta = int.parse(imputacionContable);

        itemsAsiento.add(AsientoItemData(
          cuentaId: numeroCuenta,
          debe: formaPago.value,
          haber: 0,
          observacion: 'Recibo Nro. $nroRecibo',
        ));
      }

      // 2.2. HABER - Cuentas de deudores (desde transacciones pagadas)
      for (final transaccion in transaccionesAPagar.entries) {
        // Obtener datos de la transacción (tipo comprobante, documento, importe)
        final transaccionData = await supabase
            .from('cuentas_corrientes')
            .select('tipo_comprobante, documento_numero, importe')
            .eq('idtransaccion', transaccion.key)
            .single();

        final tipoComprobante = transaccionData['tipo_comprobante'] as String;
        final documentoNumero = transaccionData['documento_numero'] as String?;
        final importeTotal = (transaccionData['importe'] as num).toDouble();

        // Obtener detalles de la transacción con cuenta contable
        final detalles = await supabase
            .from('detalle_cuentas_corrientes')
            .select('''
              importe,
              conceptos!inner(cuenta_contable)
            ''')
            .eq('idtransaccion', transaccion.key);

        // Crear items HABER proporcionales
        for (final detalle in detalles) {
          final importeDetalle = (detalle['importe'] as num).toDouble();
          // cuenta_contable almacena el NÚMERO de cuenta directamente (similar a imputacion_contable)
          // Ver database/create_conceptos.sql:15
          final numeroCuentaContable = detalle['conceptos']['cuenta_contable'] as int?;

          if (numeroCuentaContable == null) {
            throw Exception('Concepto sin cuenta contable configurada en transacción ${transaccion.key}');
          }

          // Calcular monto proporcional
          final montoProporcional = importeTotal > 0
              ? (transaccion.value / importeTotal) * importeDetalle
              : 0.0;

          // Construir observación con tipo y número de documento
          final observacion = documentoNumero != null
              ? 'Recibo Nro. $nroRecibo - $tipoComprobante $documentoNumero'
              : 'Recibo Nro. $nroRecibo - $tipoComprobante';

          itemsAsiento.add(AsientoItemData(
            cuentaId: numeroCuentaContable,
            debe: 0,
            haber: montoProporcional,
            observacion: observacion,
          ));
        }
      }

      // 3. Generar asiento usando AsientosService
      final numeroAsiento = await asientosService.crearAsiento(
        tipoAsiento: AsientosService.tipoIngreso, // Tipo 1 = Ingreso
        fecha: DateTime.now(),
        detalle: 'Recibo Nro. $nroRecibo',
        items: itemsAsiento,
        numeroComprobante: nroRecibo,
        nombrePersona: nombreCompleto,
      );

      state = const AsyncValue.data(null);

      return {
        'numero_recibo': nroRecibo,
        'numero_asiento': numeroAsiento,
      };
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Anula un recibo existente
  Future<void> anularRecibo(int numeroRecibo) async {
    state = const AsyncValue.loading();

    try {
      final service = ref.read(cobranzasServiceProvider);
      await service.anularRecibo(numeroRecibo);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Obtiene el detalle de un recibo
  Future<Map<String, dynamic>> getDetalleRecibo(int numeroRecibo) async {
    try {
      final service = ref.read(cobranzasServiceProvider);
      return await service.getDetalleRecibo(numeroRecibo);
    } catch (e) {
      rethrow;
    }
  }
}

/// Provider del notifier de cobranzas
final cobranzasNotifierProvider =
    NotifierProvider<CobranzasNotifier, AsyncValue<void>>(() {
  return CobranzasNotifier();
});
