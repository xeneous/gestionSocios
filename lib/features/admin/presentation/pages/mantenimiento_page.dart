import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';

/// Página de mantenimiento/administración
/// Solo accesible para usuarios con rol Administrador
class MantenimientoPage extends ConsumerWidget {
  const MantenimientoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(userRoleProvider);

    // Verificar permisos
    if (!userRole.puedeAccederMantenimiento) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Denegado')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'No tiene permisos para acceder a esta sección',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenimiento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Ir al inicio',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildMenuCard(
              context,
              icon: Icons.account_tree,
              title: 'Plan de Cuentas',
              subtitle: 'Gestión de cuentas contables',
              route: '/cuentas',
              color: Colors.blue,
            ),
            _buildMenuCard(
              context,
              icon: Icons.receipt,
              title: 'Conceptos Socios',
              subtitle: 'Conceptos de cuenta corriente',
              route: '/conceptos',
              color: Colors.green,
            ),
            _buildMenuCard(
              context,
              icon: Icons.payment,
              title: 'Conceptos Tesorería',
              subtitle: 'Formas de pago y conceptos',
              route: '/conceptos-tesoreria',
              color: Colors.orange,
            ),
            _buildMenuCard(
              context,
              icon: Icons.account_balance_wallet,
              title: 'Cuentas Corrientes',
              subtitle: 'Movimientos de socios',
              route: '/cuentas-corrientes',
              color: Colors.purple,
            ),
            _buildMenuCard(
              context,
              icon: Icons.manage_accounts,
              title: 'Usuarios',
              subtitle: 'Gestión de usuarios y roles',
              route: '/usuarios',
              color: Colors.deepPurple,
            ),
            _buildMenuCard(
              context,
              icon: Icons.monetization_on,
              title: 'Valores de Cuota Social',
              subtitle: 'Configuración de valores por período',
              route: '/valores-cuota',
              color: Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
