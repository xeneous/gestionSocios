import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/presentation/providers/user_role_provider.dart';
import '../../../features/socios/providers/socios_provider.dart';

/// Drawer de navegación compartido por todas las páginas principales
class AppDrawer extends ConsumerWidget {
  /// Ruta actual para highlight del item seleccionado
  final String currentRoute;

  const AppDrawer({
    required this.currentRoute,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(userRoleProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'SAO 2026',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Sistema de Gestión',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          // Dashboard
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: currentRoute == '/',
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != '/') {
                context.go('/');
              }
            },
          ),

          const Divider(),

          // ==================== ZONA SOCIOS ====================
          _buildSectionTile(
            context: context,
            ref: ref,
            icon: Icons.people,
            title: 'SOCIOS',
            color: Colors.blue,
            initiallyExpanded: _isSociosSection(currentRoute),
            children: [
              _buildMenuItem(
                context: context,
                icon: Icons.people,
                title: 'Socios',
                route: '/socios',
                currentRoute: currentRoute,
                onTap: () {
                  ref.read(sociosSearchStateProvider.notifier).clearSearch();
                  Navigator.pop(context);
                  context.go('/socios');
                },
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.medical_services,
                title: 'Listado Residentes',
                route: '/listado-residentes',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.receipt,
                title: 'Facturar Conceptos',
                route: '/facturacion-conceptos',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.payments,
                title: 'Cobranzas',
                route: '/cobranzas',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.account_balance_wallet,
                title: 'Control Cuentas Corrientes',
                route: '/resumen-cuentas-corrientes',
                currentRoute: currentRoute,
              ),
            ],
          ),

          // ==================== ZONA PROFESIONALES ====================
          _buildSectionTile(
            context: context,
            ref: ref,
            icon: Icons.people_alt,
            title: 'PROFESIONALES',
            color: Colors.teal,
            initiallyExpanded: _isProfesionalesSection(currentRoute),
            children: [
              _buildMenuItem(
                context: context,
                icon: Icons.people_alt,
                title: 'Profesionales',
                route: '/profesionales',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.receipt,
                title: 'Facturar Conceptos',
                route: '/facturacion-profesionales',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.payments,
                title: 'Cobranzas',
                route: '/cobranzas-profesionales',
                currentRoute: currentRoute,
              ),
            ],
          ),

          // ==================== ZONA PROCESOS ====================
          if (userRole.puedeFacturarMasivo)
            _buildSectionTile(
              context: context,
              ref: ref,
              icon: Icons.settings_suggest,
              title: 'PROCESOS',
              color: Colors.purple,
              initiallyExpanded: _isProcesosSection(currentRoute),
              children: [
                _buildMenuItem(
                  context: context,
                  icon: Icons.receipt_long,
                  title: 'Facturador Global',
                  route: '/facturador-global',
                  currentRoute: currentRoute,
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.credit_card,
                  title: 'Débitos Automáticos',
                  route: '/debitos-automaticos',
                  currentRoute: currentRoute,
                ),
              ],
            ),

          // ==================== ZONA CLIENTES ====================
          _buildSectionTile(
            context: context,
            ref: ref,
            icon: Icons.business,
            title: 'CLIENTES',
            color: Colors.green,
            initiallyExpanded: _isClientesSection(currentRoute),
            children: [
              _buildMenuItem(
                context: context,
                icon: Icons.business,
                title: 'Clientes / Sponsors',
                route: '/clientes',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.receipt,
                title: 'Comprobantes Ventas',
                route: '/comprobantes-clientes',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.payments,
                title: 'Cobranzas Clientes',
                route: '/cobranzas-clientes',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.account_balance_wallet,
                title: 'Saldos Clientes',
                route: '/saldos-clientes',
                currentRoute: currentRoute,
              ),
            ],
          ),

          // ==================== ZONA PROVEEDORES ====================
          _buildSectionTile(
            context: context,
            ref: ref,
            icon: Icons.store,
            title: 'PROVEEDORES',
            color: Colors.orange,
            initiallyExpanded: _isProveedoresSection(currentRoute),
            children: [
              _buildMenuItem(
                context: context,
                icon: Icons.store,
                title: 'Proveedores',
                route: '/proveedores',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.receipt_long,
                title: 'Comprobantes Compras',
                route: '/comprobantes-proveedores',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.payment,
                title: 'Orden de Pago',
                route: '/orden-pago',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.flash_on,
                title: 'Pago Directo',
                route: '/pago-directo',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.account_balance_wallet,
                title: 'Saldos Proveedores',
                route: '/saldos-proveedores',
                currentRoute: currentRoute,
              ),
            ],
          ),

          // ==================== ZONA CONTABILIDAD ====================
          _buildSectionTile(
            context: context,
            ref: ref,
            icon: Icons.account_balance,
            title: 'CONTABILIDAD',
            color: Colors.blueGrey,
            initiallyExpanded: _isContabilidadSection(currentRoute),
            children: [
              _buildMenuItem(
                context: context,
                icon: Icons.book,
                title: 'Asientos de Diario',
                route: '/asientos',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.account_balance,
                title: 'Mayor de Cuentas',
                route: '/mayor-cuentas',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.list_alt,
                title: 'Plan de Cuentas',
                route: '/cuentas',
                currentRoute: currentRoute,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.settings,
                title: 'Parámetros Contables',
                route: '/parametros-contables',
                currentRoute: currentRoute,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construye un tile de sección expandible
  Widget _buildSectionTile({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required Color color,
    required bool initiallyExpanded,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.only(left: 16),
        children: children,
      ),
    );
  }

  /// Construye un item de menú
  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
    required String currentRoute,
    VoidCallback? onTap,
  }) {
    final isSelected = currentRoute.startsWith(route) ||
        (route == '/cobranzas' && currentRoute.startsWith('/cobranzas') && !currentRoute.startsWith('/cobranzas-clientes'));

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      selected: isSelected,
      onTap: onTap ?? () {
        Navigator.pop(context);
        if (!currentRoute.startsWith(route)) {
          context.go(route);
        }
      },
    );
  }

  /// Verifica si la ruta actual pertenece a la sección Socios
  bool _isSociosSection(String route) {
    return route.startsWith('/socios') ||
        route == '/listado-residentes' ||
        route.startsWith('/facturacion-conceptos') ||
        (route.startsWith('/cobranzas') &&
            !route.startsWith('/cobranzas-clientes') &&
            !route.startsWith('/cobranzas-profesionales')) ||
        route.startsWith('/resumen-cuentas-corrientes');
  }

  /// Verifica si la ruta actual pertenece a la sección Profesionales
  bool _isProfesionalesSection(String route) {
    return route.startsWith('/profesionales') ||
        route.startsWith('/facturacion-profesionales') ||
        route.startsWith('/cobranzas-profesionales');
  }

  /// Verifica si la ruta actual pertenece a la sección Procesos
  bool _isProcesosSection(String route) {
    return route.startsWith('/facturador-global') ||
        route.startsWith('/debitos-automaticos');
  }

  /// Verifica si la ruta actual pertenece a la sección Clientes
  bool _isClientesSection(String route) {
    return route.startsWith('/clientes') ||
        route.startsWith('/comprobantes-clientes') ||
        route.startsWith('/cobranzas-clientes') ||
        route == '/saldos-clientes';
  }

  /// Verifica si la ruta actual pertenece a la sección Proveedores
  bool _isProveedoresSection(String route) {
    return route.startsWith('/proveedores') ||
        route.startsWith('/comprobantes-proveedores') ||
        route.startsWith('/orden-pago') ||
        route == '/pago-directo' ||
        route == '/saldos-proveedores';
  }

  /// Verifica si la ruta actual pertenece a la sección Contabilidad
  bool _isContabilidadSection(String route) {
    return route.startsWith('/asientos') ||
        route == '/mayor-cuentas' ||
        route.startsWith('/cuentas') ||
        route == '/parametros-contables';
  }
}
