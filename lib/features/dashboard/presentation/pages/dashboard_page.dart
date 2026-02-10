import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../models/quick_access_item.dart';
import '../../providers/quick_access_provider.dart';
import '../widgets/quick_access_selector_dialog.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userRole = ref.watch(userRoleProvider);
    final selectedIds = ref.watch(quickAccessProvider);

    // Resolver los items seleccionados manteniendo el orden
    final items = selectedIds
        .map((id) => allQuickAccessItems.where((e) => e.id == id).firstOrNull)
        .whereType<QuickAccessItem>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAO 2026'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: () => _showCustomizeDialog(context, ref, selectedIds),
            tooltip: 'Personalizar accesos',
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saludo
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
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

            // Título sección
            Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Accesos rápidos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      _showCustomizeDialog(context, ref, selectedIds),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Personalizar'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grilla de accesos rápidos
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No tenés accesos rápidos configurados',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _showCustomizeDialog(
                                context, ref, selectedIds),
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar accesos'),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount =
                            constraints.maxWidth > 900
                                ? 6
                                : constraints.maxWidth > 600
                                    ? 4
                                    : 3;
                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _QuickAccessCard(item: item);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomizeDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> currentIds,
  ) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => QuickAccessSelectorDialog(selectedIds: currentIds),
    );
    if (result != null) {
      ref.read(quickAccessProvider.notifier).save(result);
    }
  }
}

class _QuickAccessCard extends StatelessWidget {
  final QuickAccessItem item;

  const _QuickAccessCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: item.color, size: 36),
            const SizedBox(height: 10),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: item.color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
