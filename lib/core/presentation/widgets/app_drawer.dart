import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Drawer de navegación compartido por todas las páginas principales
class AppDrawer extends StatelessWidget {
  /// Ruta actual para highlight del item seleccionado
  final String currentRoute;

  const AppDrawer({
    required this.currentRoute,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
          
          // Plan de Cuentas
          ListTile(
            leading: const Icon(Icons.account_balance),
            title: const Text('Plan de Cuentas'),
            selected: currentRoute.startsWith('/cuentas'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/cuentas')) {
                context.go('/cuentas');
              }
            },
          ),
          
          // Asientos Contables
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Asientos Contables'),
            selected: currentRoute.startsWith('/asientos'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/asientos')) {
                context.go('/asientos');
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
              Navigator.pop(context);
              if (!currentRoute.startsWith('/socios')) {
                context.go('/socios');
              }
            },
          ),

          // Cuentas Corrientes
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Cuentas Corrientes'),
            selected: currentRoute.startsWith('/cuentas-corrientes'),
            onTap: () {
              Navigator.pop(context);
              if (!currentRoute.startsWith('/cuentas-corrientes')) {
                context.go('/cuentas-corrientes');
              }
            },
          ),
        ],
      ),
    );
  }
}
