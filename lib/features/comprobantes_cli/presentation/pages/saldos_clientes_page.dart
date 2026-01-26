import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../clientes/models/cliente_model.dart';
import '../../services/cobranzas_clientes_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

/// Provider para obtener saldos de todos los clientes
final saldosClientesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final service = CobranzasClientesService(supabase);

  // Obtener todos los clientes activos
  final clientesParams = ClientesSearchParams(soloActivos: true);
  final clientes = await ref.read(clientesSearchProvider(clientesParams).future);

  final saldos = <Map<String, dynamic>>[];

  for (final cliente in clientes) {
    final saldo = await service.getSaldoCliente(cliente.codigo!);
    saldos.add({
      'cliente': cliente,
      'saldo': saldo,
    });
  }

  // Ordenar por saldo descendente (los que más deben primero)
  saldos.sort((a, b) {
    final saldoA = (a['saldo'] as Map<String, double>)['saldo_total'] ?? 0;
    final saldoB = (b['saldo'] as Map<String, double>)['saldo_total'] ?? 0;
    return saldoB.compareTo(saldoA);
  });

  return saldos;
});

class SaldosClientesPage extends ConsumerStatefulWidget {
  const SaldosClientesPage({super.key});

  @override
  ConsumerState<SaldosClientesPage> createState() => _SaldosClientesPageState();
}

class _SaldosClientesPageState extends ConsumerState<SaldosClientesPage> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
  bool _soloConSaldo = true;

  @override
  Widget build(BuildContext context) {
    final saldosAsync = ref.watch(saldosClientesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saldos de Clientes/Sponsors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(saldosClientesProvider),
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/saldos-clientes'),
      body: Column(
        children: [
          // Filtro
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green[50],
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Listado de Saldos',
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
                        Text('No hay clientes con saldo pendiente'),
                      ],
                    ),
                  );
                }

                // Calcular totales
                double totalDebitos = 0;
                double totalCreditos = 0;
                for (final item in filtrados) {
                  final saldo = item['saldo'] as Map<String, double>;
                  totalDebitos += saldo['total_debitos'] ?? 0;
                  totalCreditos += saldo['total_creditos'] ?? 0;
                }

                return Column(
                  children: [
                    // Resumen
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey[100],
                      child: Row(
                        children: [
                          Text('${filtrados.length} cliente(s)'),
                          const Spacer(),
                          Text(
                            'Total a Cobrar: ${_currencyFormat.format(totalDebitos - totalCreditos)}',
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
                              DataColumn(label: Text('Débitos', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('Créditos', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('Saldo', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: filtrados.map((item) {
                              final cliente = item['cliente'] as Cliente;
                              final saldo = item['saldo'] as Map<String, double>;
                              final saldoTotal = saldo['saldo_total'] ?? 0;

                              return DataRow(
                                color: WidgetStateProperty.all(
                                  saldoTotal > 0 ? Colors.red[50] : Colors.green[50],
                                ),
                                cells: [
                                  DataCell(Text(cliente.codigo.toString())),
                                  DataCell(Text(cliente.nombreCompleto)),
                                  DataCell(Text(cliente.cuit ?? '')),
                                  DataCell(Text(
                                    _currencyFormat.format(saldo['total_debitos'] ?? 0),
                                    style: const TextStyle(color: Colors.red),
                                  )),
                                  DataCell(Text(
                                    _currencyFormat.format(saldo['total_creditos'] ?? 0),
                                    style: const TextStyle(color: Colors.green),
                                  )),
                                  DataCell(Text(
                                    _currencyFormat.format(saldoTotal),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: saldoTotal > 0 ? Colors.red : Colors.green,
                                    ),
                                  )),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility, color: Colors.blue),
                                          tooltip: 'Ver Detalle',
                                          onPressed: () => context.go('/cuenta-corriente-cliente/${cliente.codigo}'),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.payment, color: Colors.green),
                                          tooltip: 'Registrar Cobranza',
                                          onPressed: () => context.go('/cobranzas-clientes/${cliente.codigo}'),
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
                      onPressed: () => ref.invalidate(saldosClientesProvider),
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
