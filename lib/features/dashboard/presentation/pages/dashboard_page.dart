import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAO 2026 - Dashboard'),
        actions: [
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
              '¡Bienvenido al Sistema SAO 2026!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (user != null) ...[
              Text(
                'Usuario: ${user.email}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              const Text(
                'Próximamente:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Plan de Cuentas'),
              const Text('• Asientos Contables'),
              const Text('• Gestión de Socios'),
              const Text('• Facturación'),
              const Text('• Compras y Ventas'),
            ],
          ],
        ),
      ),
    );
  }
}
