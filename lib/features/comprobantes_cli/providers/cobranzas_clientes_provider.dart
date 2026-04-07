import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cobranzas_clientes_service.dart';
import '../../asientos/services/asientos_service.dart';
import '../../asientos/providers/asientos_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../parametros/models/parametro_contable_model.dart';

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

  /// Genera un nuevo recibo de cobranza con su asiento contable.
  ///
  /// Siempre retorna un mapa con numero_recibo, id_transaccion.
  /// Si el asiento falla, retorna además [asiento_warning] con el mensaje.
  /// Si el recibo mismo falla, lanza excepción.
  ///
  /// Asiento tipo Ingreso (1):
  ///   DEBE: cuenta(s) de tesorería (una línea por cada forma de pago)
  ///   HABER: CUENTA_SPONSORS (activo baja porque el cliente pagó)
  Future<Map<String, dynamic>> generarRecibo({
    required int clienteId,
    required Map<int, double> transaccionesAPagar,
    required Map<int, double> formasPago,
    int? operadorId,
    DateTime? fecha,
  }) async {
    state = const AsyncValue.loading();

    try {
      final cobranzasService = ref.read(cobranzasClientesServiceProvider);
      final asientosService = ref.read(asientosServiceProvider);
      final supabase = ref.read(supabaseProvider);

      // 0. Nombre del cliente para el detalle del asiento
      final clienteData = await supabase
          .from('clientes')
          .select('razon_social')
          .eq('codigo', clienteId)
          .maybeSingle();

      final nombreCompleto =
          (clienteData?['razon_social'] as String?)?.trim() ??
              'Cliente $clienteId';

      // 1. Pre-validar parámetros contables antes de grabar nada
      await _prevalidar(supabase, formasPago);

      // 2. Generar el recibo (ya validado, no debería fallar por datos faltantes)
      final resultado = await cobranzasService.generarRecibo(
        clienteId: clienteId,
        transaccionesAPagar: transaccionesAPagar,
        formasPago: formasPago,
        operadorId: operadorId,
        fecha: fecha,
      );

      final numeroRecibo = resultado['numero_recibo'] as int;
      final idTransaccion = resultado['id_transaccion'] as int;
      final operacionId = resultado['operacion_id'] as int;
      final totalCobrado = formasPago.values.fold(0.0, (a, b) => a + b);

      // 2. Intentar generar asiento contable
      try {
        // Obtener CUENTA_SPONSORS desde parámetros
        final paramResponse = await supabase
            .from('parametros_contables')
            .select('valor')
            .eq('clave', ParametroContable.cuentaSponsors)
            .maybeSingle();

        if (paramResponse == null || paramResponse['valor'] == null) {
          throw Exception(
              'No se encontró CUENTA_SPONSORS en parámetros_contables');
        }

        final cuentaSponsors = int.tryParse(paramResponse['valor'].toString());
        if (cuentaSponsors == null) {
          throw Exception(
              'El valor de CUENTA_SPONSORS no es un número válido: ${paramResponse['valor']}');
        }

        // Construir items del asiento
        final itemsAsiento = <AsientoItemData>[];

        // DEBE: una línea por cada forma de pago (tesorería entra)
        for (final formaPago in formasPago.entries) {
          final conceptoTesoreria = await supabase
              .from('conceptos_tesoreria')
              .select('imputacion_contable')
              .eq('id', formaPago.key)
              .maybeSingle();

          final imputacionContable =
              conceptoTesoreria?['imputacion_contable'] as String?;

          if (imputacionContable == null || imputacionContable.isEmpty) {
            throw Exception(
                'Concepto de tesorería ${formaPago.key} no tiene imputación contable configurada');
          }

          final cuentaId = int.tryParse(imputacionContable);
          if (cuentaId == null) {
            throw Exception(
                'Imputación contable del concepto ${formaPago.key} no es un número válido: $imputacionContable');
          }

          itemsAsiento.add(AsientoItemData(
            cuentaId: cuentaId,
            debe: formaPago.value,
            haber: 0,
          ));
        }

        // HABER: CUENTA_SPONSORS por el total cobrado (activo baja)
        itemsAsiento.add(AsientoItemData(
          cuentaId: cuentaSponsors,
          debe: 0,
          haber: totalCobrado,
        ));

        // Crear asiento tipo Ingreso (1)
        final numeroAsiento = await asientosService.crearAsiento(
          tipoAsiento: AsientosService.tipoIngreso,
          fecha: DateTime.now(),
          detalle: 'Recibo Cli Nro. $numeroRecibo - $nombreCompleto',
          items: itemsAsiento,
          numeroComprobante: numeroRecibo,
          nombrePersona: nombreCompleto,
        );

        // Actualizar operaciones_contables con el asiento generado
        final anioMes = DateTime.now().year * 100 + DateTime.now().month;
        await supabase.from('operaciones_contables').update({
          'asiento_numero': numeroAsiento,
          'asiento_anio_mes': anioMes,
          'asiento_tipo': AsientosService.tipoIngreso,
        }).eq('id', operacionId);

        state = const AsyncValue.data(null);

        return {
          'numero_recibo': numeroRecibo,
          'numero_asiento': numeroAsiento,
          'id_transaccion': idTransaccion,
        };
      } catch (e) {
        // El recibo ya fue guardado; el asiento falló → devolvemos con warning
        state = const AsyncValue.data(null);
        return {
          'numero_recibo': numeroRecibo,
          'id_transaccion': idTransaccion,
          'asiento_warning': e.toString(),
        };
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Verifica que todos los datos contables necesarios existan antes de grabar.
  /// Lanza [Exception] con mensaje descriptivo si falta algo.
  Future<void> _prevalidar(
    SupabaseClient supabase,
    Map<int, double> formasPago,
  ) async {
    final errores = <String>[];

    // Verificar CUENTA_SPONSORS
    final paramResponse = await supabase
        .from('parametros_contables')
        .select('valor')
        .eq('clave', ParametroContable.cuentaSponsors)
        .maybeSingle();

    if (paramResponse == null || paramResponse['valor'] == null) {
      errores.add('Falta el parámetro CUENTA_SPONSORS en parámetros_contables');
    } else if (int.tryParse(paramResponse['valor'].toString()) == null) {
      errores.add(
          'CUENTA_SPONSORS no es un número válido: ${paramResponse['valor']}');
    }

    // Verificar imputacion_contable de cada forma de pago
    for (final conceptoId in formasPago.keys) {
      final concepto = await supabase
          .from('conceptos_tesoreria')
          .select('descripcion, imputacion_contable')
          .eq('id', conceptoId)
          .maybeSingle();

      if (concepto == null) {
        errores.add('Concepto de tesorería $conceptoId no existe');
        continue;
      }

      final descripcion = concepto['descripcion'] as String? ?? 'ID $conceptoId';
      final imputacion = concepto['imputacion_contable'] as String?;

      if (imputacion == null || imputacion.trim().isEmpty) {
        errores.add('"$descripcion" no tiene imputación contable configurada');
      } else if (int.tryParse(imputacion.trim()) == null) {
        errores.add(
            '"$descripcion" tiene imputación contable inválida: $imputacion');
      }
    }

    if (errores.isNotEmpty) {
      throw Exception(
          'No se puede generar el recibo:\n${errores.map((e) => '• $e').join('\n')}');
    }
  }
}

/// Provider del notifier de cobranzas de clientes
final cobranzasClientesNotifierProvider =
    NotifierProvider<CobranzasClientesNotifier, AsyncValue<void>>(() {
  return CobranzasClientesNotifier();
});
