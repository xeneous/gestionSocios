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

          // Socios
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Socios'),
            selected: currentRoute.startsWith('/socios'),
            onTap: () {
              // Limpiar búsqueda al entrar desde el menú
              ref.read(sociosSearchStateProvider.notifier).clearSearch();
              Navigator.pop(context);
              context.go('/socios');
            },
          ),

          // Cobranzas
          ListTile(
            leading: const Icon(Icons.payments),
            title: const Text('Cobranzas'),
            selected: currentRoute.startsWith('/cobranzas'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/cobranzas')) {
                context.go('/cobranzas');
              }
            },
          ),

          // Facturación de Conceptos
          ListTile(
            leading: const Icon(Icons.receipt),
            title: const Text('Facturar Conceptos'),
            selected: currentRoute.startsWith('/facturacion-conceptos'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/facturacion-conceptos')) {
                context.go('/facturacion-conceptos');
              }
            },
          ),

          // Resumen Cuentas Corrientes
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Resumen Cuentas Corrientes'),
            selected: currentRoute.startsWith('/resumen-cuentas-corrientes'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/resumen-cuentas-corrientes')) {
                context.go('/resumen-cuentas-corrientes');
              }
            },
          ),

          // Solo para supervisor y administrador
          if (userRole.puedeFacturarMasivo) ...[
            const Divider(),

            // Facturador Global de Cuotas
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.green),
              title: const Text('Facturador Global'),
              selected: currentRoute.startsWith('/facturador-global'),
              onTap: () {
                Navigator.pop(context);
                if (!currentRoute.startsWith('/facturador-global')) {
                  context.go('/facturador-global');
                }
              },
            ),

            // Débitos Automáticos
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.purple),
              title: const Text('Débitos Automáticos'),
              selected: currentRoute.startsWith('/debitos-automaticos'),
              onTap: () {
                Navigator.pop(context);
                if (!currentRoute.startsWith('/debitos-automaticos')) {
                  context.go('/debitos-automaticos');
                }
              },
            ),
          ],

          const Divider(),

          // Clientes (Sponsors)
          ListTile(
            leading: const Icon(Icons.business, color: Colors.green),
            title: const Text('Clientes / Sponsors'),
            selected: currentRoute.startsWith('/clientes'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/clientes')) {
                context.go('/clientes');
              }
            },
          ),

          // Proveedores
          ListTile(
            leading: const Icon(Icons.store, color: Colors.orange),
            title: const Text('Proveedores'),
            selected: currentRoute.startsWith('/proveedores'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/proveedores')) {
                context.go('/proveedores');
              }
            },
          ),

          // Comprobantes de Proveedores
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.orange),
            title: const Text('Comprobantes Compras'),
            selected: currentRoute.startsWith('/comprobantes-proveedores'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/comprobantes-proveedores')) {
                context.go('/comprobantes-proveedores');
              }
            },
          ),

          // Comprobantes de Clientes
          ListTile(
            leading: const Icon(Icons.receipt, color: Colors.green),
            title: const Text('Comprobantes Ventas'),
            selected: currentRoute.startsWith('/comprobantes-clientes'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/comprobantes-clientes')) {
                context.go('/comprobantes-clientes');
              }
            },
          ),

          const Divider(),

          // Asientos de Diario
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Asientos de Diario'),
            selected: currentRoute.startsWith('/asientos'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/asientos')) {
                context.go('/asientos');
              }
            },
          ),
        ],
      ),
    );
  }
}
