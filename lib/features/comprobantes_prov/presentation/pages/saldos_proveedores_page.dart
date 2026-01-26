import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../proveedores/providers/proveedores_provider.dart';
import '../../../proveedores/models/proveedor_model.dart';
import '../../services/orden_pago_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

/// Provider para obtener saldos de todos los proveedores
final saldosProveedoresProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final service = OrdenPagoService(supabase);

  // Obtener todos los proveedores activos
  final proveedoresParams = ProveedoresSearchParams(soloActivos: true);
  final proveedores = await ref.read(proveedoresSearchProvider(proveedoresParams).future);

  final saldos = <Map<String, dynamic>>[];

  for (final proveedor in proveedores) {
    final saldo = await service.getSaldoProveedor(proveedor.codigo!);
    saldos.add({
      'proveedor': proveedor,
      'saldo': saldo,
    });
  }

  // Ordenar por saldo descendente (los que más debemos primero)
  saldos.sort((a, b) {
    final saldoA = (a['saldo'] as Map<String, double>)['saldo_total'] ?? 0;
    final saldoB = (b['saldo'] as Map<String, double>)['saldo_total'] ?? 0;
    return saldoB.compareTo(saldoA);
  });

  return saldos;
});

class SaldosProveedoresPage extends ConsumerStatefulWidget {
  const SaldosProveedoresPage({super.key});

  @override
  ConsumerState<SaldosProveedoresPage> createState() => _SaldosProveedoresPageState();
}

class _SaldosProveedoresPageState extends ConsumerState<SaldosProveedoresPage> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
  bool _soloConSaldo = true;

  @override
  Widget build(BuildContext context) {
    final saldosAsync = ref.watch(saldosProveedoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saldos de Proveedores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(saldosProveedoresProvider),
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/saldos-proveedores'),
      body: Column(
        children: [
          // Filtro
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange[50],
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Listado de Saldos a Pagar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilterChip(
                  label: Text(_soloConSaldo ? 'Solo con saldo' : 'Todos'),
                  selected: _soloConSaldo,
                  onSelected: (value) {
                    setState(() => _soloConSaldo = value);
                  },
                ),
              ],
            ),
          ),
          // Lista
          Expanded(
            child: saldosAsync.when(
              data: (saldos) {
                final filtrados = _soloConSaldo
                    ? saldos.where((s) {
                        final saldo = (s['saldo'] as Map<String, double>)['saldo_total'] ?? 0;
                        return saldo.abs() > 0.01;
                      }).toList()
                    : saldos;

                if (filtrados.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text('No hay proveedores con saldo pendiente'),
                      ],
                    ),
                  );
                }

                // Calcular totales
                double totalFacturas = 0;
                double totalPagos = 0;
                for (final item in filtrados) {
                  final saldo = item['saldo'] as Map<String, double>;
                  totalFacturas += saldo['total_facturas'] ?? 0;
                  totalPagos += saldo['total_pagos'] ?? 0;
                }

                return Column(
                  children: [
                    // Resumen
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey[100],
                      child: Row(
                        children: [
                          Text('${filtrados.length} proveedor(es)'),
                          const Spacer(),
                          Text(
                            'Total a Pagar: ${_currencyFormat.format(totalFacturas - totalPagos)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // Tabla
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Razón Social', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('CUIT', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Facturas', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('Pagos/NC', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('Saldo', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: filtrados.map((item) {
                              final proveedor = item['proveedor'] as Proveedor;
                              final saldo = item['saldo'] as Map<String, double>;
                              final saldoTotal = saldo['saldo_total'] ?? 0;

                              return DataRow(
                                color: WidgetStateProperty.all(
                                  saldoTotal > 0 ? Colors.orange[50] : Colors.green[50],
                                ),
                                cells: [
                                  DataCell(Text(proveedor.codigo.toString())),
                                  DataCell(Text(proveedor.nombreCompleto)),
                                  DataCell(Text(proveedor.cuit ?? '')),
                                  DataCell(Text(
                                    _currencyFormat.format(saldo['total_facturas'] ?? 0),
                                    style: const TextStyle(color: Colors.red),
                                  )),
                                  DataCell(Text(
                                    _currencyFormat.format(saldo['total_pagos'] ?? 0),
                                    style: const TextStyle(color: Colors.green),
                                  )),
                                  DataCell(Text(
                                    _currencyFormat.format(saldoTotal),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: saldoTotal > 0 ? Colors.orange : Colors.green,
                                    ),
                                  )),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility, color: Colors.blue),
                                          tooltip: 'Ver Detalle',
                                          onPressed: () => context.go('/cuenta-corriente-proveedor/${proveedor.codigo}'),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.payment, color: Colors.orange),
                                          tooltip: 'Registrar Pago',
                                          onPressed: () => context.go('/orden-pago/${proveedor.codigo}'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(saldosProveedoresProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
