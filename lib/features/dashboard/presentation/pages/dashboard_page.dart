import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userRole = ref.watch(userRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAO - Dashboard'),
        actions: [
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.dashboard,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              '¡Bienvenido al Sistema SAO!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (user != null) ...[
              Text(
                'Usuario: ${user.email}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                'Rol: ${userRole.displayName}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (userRole.puedeAccederMantenimiento) ...[
                ElevatedButton.icon(
                  onPressed: () => context.go('/mantenimiento'),
                  icon: const Icon(Icons.settings),
                  label: const Text('Ir a Mantenimiento'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (userRole.puedeFacturarMasivo) ...[
                ElevatedButton.icon(
                  onPressed: () => context.go('/facturador-global'),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Facturador Global de Cuotas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.go('/debitos-automaticos'),
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Presentación Débitos Automáticos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Módulos disponibles:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Gestión de Socios'),
              const Text('• Cuentas Corrientes'),
              const Text('• Cobranzas'),
              const Text('• Asientos Contables'),
              const Text('• Plan de Cuentas'),
            ],
          ],
        ),
      ),
    );
  }
}
