import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../providers/dashboard_stats_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userRole = ref.watch(userRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAO 2026'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(sociosStatsProvider);
              ref.invalidate(tesoreriaStatsProvider);
              ref.invalidate(contabilidadStatsProvider);
            },
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.lock_reset),
            onPressed: () => context.go('/change-password'),
            tooltip: 'Cambiar Contraseña',
          ),
          if (userRole.puedeAccederMantenimiento)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.go('/mantenimiento'),
              tooltip: 'Mantenimiento',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).signOut();
            },
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saludo
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(Icons.waving_hand, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Hola, ${user.email?.split('@').first ?? 'Usuario'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Chip(
                      label: Text(userRole.displayName),
                      backgroundColor: Colors.blue.shade100,
                    ),
                  ],
                ),
              ),

            // Grid Bento Box
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final isMedium = constraints.maxWidth > 600;

                if (isWide) {
                  return _buildWideLayout(context, ref);
                } else if (isMedium) {
                  return _buildMediumLayout(context, ref);
                } else {
                  return _buildNarrowLayout(context, ref);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Layout para pantallas anchas (desktop)
  Widget _buildWideLayout(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Primera fila: Socios (grande) + Tesorería (2 cards)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SOCIOS - Card grande
              Expanded(
                flex: 2,
                child: _buildSociosCard(context, ref),
              ),
              const SizedBox(width: 16),
              // TESORERÍA - 2 cards verticales
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(child: _buildCobranzasCard(context, ref)),
                    const SizedBox(height: 16),
                    Expanded(child: _buildPagosCard(context, ref)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Segunda fila: Accesos rápidos + Contabilidad
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accesos rápidos
              Expanded(
                flex: 1,
                child: _buildAccesosRapidosCard(context),
              ),
              const SizedBox(width: 16),
              // Contabilidad
              Expanded(
                flex: 2,
                child: _buildContabilidadCard(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Layout para pantallas medianas (tablet)
  Widget _buildMediumLayout(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildSociosCard(context, ref),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildCobranzasCard(context, ref)),
            const SizedBox(width: 16),
            Expanded(child: _buildPagosCard(context, ref)),
          ],
        ),
        const SizedBox(height: 16),
        _buildAccesosRapidosCard(context),
        const SizedBox(height: 16),
        _buildContabilidadCard(context, ref),
      ],
    );
  }

  /// Layout para pantallas angostas (móvil)
  Widget _buildNarrowLayout(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildSociosCard(context, ref),
        const SizedBox(height: 16),
        _buildCobranzasCard(context, ref),
        const SizedBox(height: 16),
        _buildPagosCard(context, ref),
        const SizedBox(height: 16),
        _buildAccesosRapidosCard(context),
        const SizedBox(height: 16),
        _buildContabilidadCard(context, ref),
      ],
    );
  }

  /// Card de SOCIOS - La base del sistema
  Widget _buildSociosCard(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(sociosStatsProvider);

    return Card(
      color: Colors.blue.shade50,
      elevation: 2,
      child: InkWell(
        onTap: () => context.go('/socios'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.people, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SOCIOS',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        'Gestión integral de socios',
                        style: TextStyle(color: Colors.blue.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              statsAsync.when(
                data: (stats) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      icon: Icons.people,
                      value: stats.sociosActivos.toString(),
                      label: 'Activos',
                      color: Colors.blue,
                    ),
                    _buildStatItem(
                      context,
                      icon: Icons.medical_services,
                      value: stats.totalResidentes.toString(),
                      label: 'Residentes',
                      color: Colors.teal,
                    ),
                    _buildStatItem(
                      context,
                      icon: Icons.account_balance_wallet,
                      value: _currencyFormat.format(stats.saldoPendiente),
                      label: 'Por cobrar',
                      color: Colors.orange,
                    ),
                    if (stats.comprobantesVencidos > 0)
                      _buildStatItem(
                        context,
                        icon: Icons.warning,
                        value: stats.comprobantesVencidos.toString(),
                        label: 'Vencidos',
                        color: Colors.red,
                      ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error cargando estadísticas'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              // Accesos rápidos de socios
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickAction(context, 'Socios', Icons.people, '/socios'),
                  _buildQuickAction(context, 'Residentes', Icons.medical_services, '/listado-residentes'),
                  _buildQuickAction(context, 'Facturar', Icons.receipt, '/facturacion-conceptos'),
                  _buildQuickAction(context, 'Cobrar', Icons.payments, '/cobranzas'),
                  _buildQuickAction(context, 'Ctas Ctes', Icons.account_balance_wallet, '/resumen-cuentas-corrientes'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de Cobranzas
  Widget _buildCobranzasCard(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(tesoreriaStatsProvider);

    return Card(
      color: Colors.green.shade50,
      elevation: 2,
      child: InkWell(
        onTap: () => context.go('/cobranzas'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_downward, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'INGRESOS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              statsAsync.when(
                data: (stats) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currencyFormat.format(stats.cobranzasHoy),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text('Hoy (${stats.recibosHoy} recibos)', style: TextStyle(color: Colors.green.shade600)),
                    const SizedBox(height: 8),
                    Text(
                      'Mes: ${_currencyFormat.format(stats.cobranzasMes)}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
                loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const Text('-'),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/cobranzas'),
                    icon: const Icon(Icons.people, size: 16),
                    label: const Text('Socios'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/cobranzas-clientes'),
                    icon: const Icon(Icons.business, size: 16),
                    label: const Text('Clientes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de Pagos
  Widget _buildPagosCard(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(tesoreriaStatsProvider);

    return Card(
      color: Colors.orange.shade50,
      elevation: 2,
      child: InkWell(
        onTap: () => context.go('/orden-pago'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_upward, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'EGRESOS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              statsAsync.when(
                data: (stats) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currencyFormat.format(stats.pagosHoy),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    Text('Hoy (${stats.ordenesHoy} OPs)', style: TextStyle(color: Colors.orange.shade600)),
                    const SizedBox(height: 8),
                    Text(
                      'Mes: ${_currencyFormat.format(stats.pagosMes)}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
                loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const Text('-'),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/orden-pago'),
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('OP'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/pago-directo'),
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: const Text('Directo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de Accesos Rápidos
  Widget _buildAccesosRapidosCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Accesos Rápidos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildBigQuickAction(
                  context,
                  'Cobrar Socio',
                  Icons.payments,
                  Colors.blue,
                  '/cobranzas',
                ),
                _buildBigQuickAction(
                  context,
                  'Cobrar Cliente',
                  Icons.business,
                  Colors.green,
                  '/cobranzas-clientes',
                ),
                _buildBigQuickAction(
                  context,
                  'Pagar Proveedor',
                  Icons.store,
                  Colors.orange,
                  '/orden-pago',
                ),
                _buildBigQuickAction(
                  context,
                  'Pago Directo',
                  Icons.flash_on,
                  Colors.deepOrange,
                  '/pago-directo',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Card de Contabilidad
  Widget _buildContabilidadCard(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(contabilidadStatsProvider);

    return Card(
      color: Colors.blueGrey.shade50,
      elevation: 2,
      child: InkWell(
        onTap: () => context.go('/asientos'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONTABILIDAD',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                      Text(
                        'Clientes, Proveedores y Mayor',
                        style: TextStyle(color: Colors.blueGrey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              statsAsync.when(
                data: (stats) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildContabilidadStat(
                      context,
                      'Clientes',
                      _currencyFormat.format(stats.saldoClientes),
                      Colors.green,
                      Icons.trending_up,
                    ),
                    _buildContabilidadStat(
                      context,
                      'Proveedores',
                      _currencyFormat.format(stats.saldoProveedores),
                      Colors.orange,
                      Icons.trending_down,
                    ),
                    _buildContabilidadStat(
                      context,
                      'Asientos (mes)',
                      stats.asientosMes.toString(),
                      Colors.blueGrey,
                      Icons.book,
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error cargando estadísticas'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              // Accesos rápidos de contabilidad
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickAction(context, 'Asientos', Icons.book, '/asientos'),
                  _buildQuickAction(context, 'Mayor', Icons.account_balance, '/mayor-cuentas'),
                  _buildQuickAction(context, 'Clientes', Icons.business, '/clientes'),
                  _buildQuickAction(context, 'Proveedores', Icons.store, '/proveedores'),
                  _buildQuickAction(context, 'Saldos Cli', Icons.account_balance_wallet, '/saldos-clientes'),
                  _buildQuickAction(context, 'Saldos Prov', Icons.account_balance_wallet, '/saldos-proveedores'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildContabilidadStat(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, String route) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () => context.go(route),
    );
  }

  Widget _buildBigQuickAction(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    String route,
  ) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
