import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Estadísticas del módulo Socios
class SociosStats {
  final int sociosActivos;
  final int totalResidentes;
  final double saldoPendiente;
  final int comprobantesVencidos;

  SociosStats({
    required this.sociosActivos,
    required this.totalResidentes,
    required this.saldoPendiente,
    required this.comprobantesVencidos,
  });
}

/// Estadísticas del módulo Tesorería
class TesoreriaStats {
  final double cobranzasHoy;
  final double cobranzasMes;
  final double pagosHoy;
  final double pagosMes;
  final int recibosHoy;
  final int ordenesHoy;

  TesoreriaStats({
    required this.cobranzasHoy,
    required this.cobranzasMes,
    required this.pagosHoy,
    required this.pagosMes,
    required this.recibosHoy,
    required this.ordenesHoy,
  });
}

/// Estadísticas del módulo Contabilidad
class ContabilidadStats {
  final double saldoClientes;
  final double saldoProveedores;
  final int asientosMes;
  final String? ultimoAsiento;

  ContabilidadStats({
    required this.saldoClientes,
    required this.saldoProveedores,
    required this.asientosMes,
    this.ultimoAsiento,
  });
}

/// Provider de estadísticas de Socios
final sociosStatsProvider = FutureProvider<SociosStats>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  // Socios activos
  final sociosResponse = await supabase
      .from('socios')
      .select('id')
      .eq('activo', true)
      .count(CountOption.exact);

  // Total residentes (usando la vista o tabla de residentes)
  int totalResidentes = 0;
  try {
    final residentesResponse = await supabase
        .from('socios')
        .select('id')
        .eq('activo', true)
        .not('fecha_ingreso_resid', 'is', null)
        .count(CountOption.exact);
    totalResidentes = residentesResponse.count;
  } catch (_) {
    // Si falla, dejamos en 0
  }

  // Saldo pendiente de socios (cuentas corrientes)
  double saldoPendiente = 0;
  try {
    final saldoResponse = await supabase
        .from('cuentas_corrientes')
        .select('importe')
        .gt('importe', 0);

    for (final row in saldoResponse as List) {
      saldoPendiente += (row['importe'] as num?)?.toDouble() ?? 0;
    }
  } catch (_) {}

  // Comprobantes vencidos (fecha_vencimiento < hoy)
  int comprobantesVencidos = 0;
  try {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final vencidosResponse = await supabase
        .from('cuentas_corrientes')
        .select('id')
        .lt('fecha_vencimiento', hoy)
        .gt('importe', 0)
        .count(CountOption.exact);
    comprobantesVencidos = vencidosResponse.count;
  } catch (_) {}

  return SociosStats(
    sociosActivos: sociosResponse.count,
    totalResidentes: totalResidentes,
    saldoPendiente: saldoPendiente,
    comprobantesVencidos: comprobantesVencidos,
  );
});

/// Provider de estadísticas de Tesorería
final tesoreriaStatsProvider = FutureProvider<TesoreriaStats>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final hoy = DateTime.now();
  final inicioMes = DateTime(hoy.year, hoy.month, 1);
  final hoyStr = hoy.toIso8601String().split('T')[0];
  final inicioMesStr = inicioMes.toIso8601String().split('T')[0];

  double cobranzasHoy = 0;
  double cobranzasMes = 0;
  int recibosHoy = 0;

  // Cobranzas de socios (recibos)
  try {
    // Hoy
    final recibosHoyResponse = await supabase
        .from('recibos_header')
        .select('total')
        .eq('fecha', hoyStr);

    for (final row in recibosHoyResponse as List) {
      cobranzasHoy += (row['total'] as num?)?.toDouble() ?? 0;
    }
    recibosHoy = (recibosHoyResponse as List).length;

    // Mes
    final recibosMesResponse = await supabase
        .from('recibos_header')
        .select('total')
        .gte('fecha', inicioMesStr)
        .lte('fecha', hoyStr);

    for (final row in recibosMesResponse as List) {
      cobranzasMes += (row['total'] as num?)?.toDouble() ?? 0;
    }
  } catch (_) {}

  // Cobranzas de clientes
  try {
    final cliHoyResponse = await supabase
        .from('ven_cli_header')
        .select('total_importe')
        .eq('fecha', hoyStr)
        .eq('tipo_comprobante', 3); // Recibos

    for (final row in cliHoyResponse as List) {
      cobranzasHoy += (row['total_importe'] as num?)?.toDouble() ?? 0;
    }

    final cliMesResponse = await supabase
        .from('ven_cli_header')
        .select('total_importe')
        .gte('fecha', inicioMesStr)
        .lte('fecha', hoyStr)
        .eq('tipo_comprobante', 3);

    for (final row in cliMesResponse as List) {
      cobranzasMes += (row['total_importe'] as num?)?.toDouble() ?? 0;
    }
  } catch (_) {}

  double pagosHoy = 0;
  double pagosMes = 0;
  int ordenesHoy = 0;

  // Órdenes de pago
  try {
    final opHoyResponse = await supabase
        .from('comp_prov_header')
        .select('total_importe')
        .eq('fecha', hoyStr)
        .eq('tipo_comprobante', 3); // Órdenes de pago

    for (final row in opHoyResponse as List) {
      pagosHoy += (row['total_importe'] as num?)?.toDouble() ?? 0;
    }
    ordenesHoy = (opHoyResponse as List).length;

    final opMesResponse = await supabase
        .from('comp_prov_header')
        .select('total_importe')
        .gte('fecha', inicioMesStr)
        .lte('fecha', hoyStr)
        .eq('tipo_comprobante', 3);

    for (final row in opMesResponse as List) {
      pagosMes += (row['total_importe'] as num?)?.toDouble() ?? 0;
    }
  } catch (_) {}

  return TesoreriaStats(
    cobranzasHoy: cobranzasHoy,
    cobranzasMes: cobranzasMes,
    pagosHoy: pagosHoy,
    pagosMes: pagosMes,
    recibosHoy: recibosHoy,
    ordenesHoy: ordenesHoy,
  );
});

/// Provider de estadísticas de Contabilidad
final contabilidadStatsProvider = FutureProvider<ContabilidadStats>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final hoy = DateTime.now();
  final anioMes = hoy.year * 100 + hoy.month;

  double saldoClientes = 0;
  double saldoProveedores = 0;

  // Saldo clientes (facturas - cancelado)
  try {
    final cliResponse = await supabase
        .from('ven_cli_header')
        .select('total_importe, cancelado')
        .eq('tipo_comprobante', 1); // Facturas

    for (final row in cliResponse as List) {
      final total = (row['total_importe'] as num?)?.toDouble() ?? 0;
      final cancelado = (row['cancelado'] as num?)?.toDouble() ?? 0;
      saldoClientes += (total - cancelado);
    }
  } catch (_) {}

  // Saldo proveedores (facturas pendientes)
  try {
    final provResponse = await supabase
        .from('comp_prov_header')
        .select('total_importe, cancelado')
        .eq('tipo_comprobante', 1) // Facturas
        .or('estado.is.null,estado.neq.P');

    for (final row in provResponse as List) {
      final total = (row['total_importe'] as num?)?.toDouble() ?? 0;
      final cancelado = (row['cancelado'] as num?)?.toDouble() ?? 0;
      saldoProveedores += (total - cancelado);
    }
  } catch (_) {}

  // Asientos del mes
  int asientosMes = 0;
  String? ultimoAsiento;
  try {
    final asientosResponse = await supabase
        .from('asientos_header')
        .select('asiento, detalle')
        .eq('anio_mes', anioMes)
        .order('asiento', ascending: false)
        .limit(1);

    if ((asientosResponse as List).isNotEmpty) {
      ultimoAsiento = asientosResponse[0]['detalle'] as String?;
    }

    final countResponse = await supabase
        .from('asientos_header')
        .select('asiento')
        .eq('anio_mes', anioMes)
        .count(CountOption.exact);
    asientosMes = countResponse.count;
  } catch (_) {}

  return ContabilidadStats(
    saldoClientes: saldoClientes,
    saldoProveedores: saldoProveedores,
    asientosMes: asientosMes,
    ultimoAsiento: ultimoAsiento,
  );
});
