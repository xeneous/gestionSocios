import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/profesionales_provider.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class ProfesionalesListPage extends ConsumerStatefulWidget {
  const ProfesionalesListPage({super.key});

  @override
  ConsumerState<ProfesionalesListPage> createState() =>
      _ProfesionalesListPageState();
}

class _ProfesionalesListPageState extends ConsumerState<ProfesionalesListPage> {
  final _apellidoController = TextEditingController();
  final _nombreController = TextEditingController();
  final _dniController = TextEditingController();

  @override
  void dispose() {
    _apellidoController.dispose();
    _nombreController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final searchParams = ProfesionalesSearchParams(
      apellido: _apellidoController.text.trim(),
      nombre: _nombreController.text.trim(),
      numeroDocumento: _dniController.text.trim(),
      soloActivos: true,
    );

    ref.read(profesionalesSearchStateProvider.notifier).update(searchParams);
  }

  void _clearSearch() {
    _apellidoController.clear();
    _nombreController.clear();
    _dniController.clear();

    ref.read(profesionalesSearchStateProvider.notifier).update(
        ProfesionalesSearchParams(soloActivos: true));
  }

  @override
  Widget build(BuildContext context) {
    final searchParams = ref.watch(profesionalesSearchStateProvider);
    final profesionalesAsync = ref.watch(profesionalesSearchProvider(searchParams));
    final userRole = ref.watch(userRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profesionales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/profesionales'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/profesionales/nuevo'),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Profesional'),
      ),
      body: Column(
        children: [
          // Search form
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Búsqueda de Profesionales',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _apellidoController,
                            decoration: const InputDecoration(
                              labelText: 'Apellido',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nombreController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _dniController,
                            decoration: const InputDecoration(
                              labelText: 'DNI',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.credit_card),
                            ),
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _performSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: profesionalesAsync.when(
              data: (profesionales) {
                if (profesionales.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No se encontraron profesionales',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Intente con otros criterios de búsqueda',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: profesionales.length,
                  itemBuilder: (context, index) {
                    final profesional = profesionales[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: profesional.activo
                              ? Colors.green
                              : Colors.red,
                          child: Text(
                            profesional.apellido[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          profesional.nombreCompleto,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (profesional.numeroDocumento != null)
                              Text('DNI: ${profesional.numeroDocumento}'),
                            if (profesional.email != null)
                              Text('Email: ${profesional.email}'),
                            if (profesional.telefono != null)
                              Text('Tel: ${profesional.telefono}'),
                            Row(
                              children: [
                                Icon(
                                  profesional.activo
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 16,
                                  color: profesional.activo
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  profesional.activo ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                    color: profesional.activo
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.account_balance_wallet,
                                  color: Colors.teal),
                              onPressed: () => context.go(
                                  '/profesionales/${profesional.id}/cuenta-corriente'),
                              tooltip: 'Cuenta Corriente',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => context.go(
                                  '/profesionales/${profesional.id}/editar'),
                              tooltip: 'Editar',
                            ),
                            if (userRole.esAdministrador)
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Eliminar profesional'),
                                      content: Text(
                                          '¿Eliminar permanentemente a ${profesional.nombreCompleto}? Esta acción no se puede deshacer.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: FilledButton.styleFrom(
                                              backgroundColor: Colors.red),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    try {
                                      await ref
                                          .read(profesionalesNotifierProvider
                                              .notifier)
                                          .deleteProfesional(profesional.id!);
                                      ref.invalidate(
                                          profesionalesSearchProvider);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Profesional eliminado')),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  }
                                },
                                tooltip: 'Eliminar',
                              ),
                            if (userRole.esAdministrador)
                              IconButton(
                                icon: Icon(
                                  profesional.activo
                                      ? Icons.person_off
                                      : Icons.person,
                                  color: profesional.activo
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(profesional.activo
                                          ? 'Dar de baja'
                                          : 'Reactivar'),
                                      content: Text(profesional.activo
                                          ? '¿Dar de baja a ${profesional.nombreCompleto}?'
                                          : '¿Reactivar a ${profesional.nombreCompleto}?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Confirmar'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    try {
                                      if (profesional.activo) {
                                        await ref
                                            .read(profesionalesNotifierProvider
                                                .notifier)
                                            .darDeBajaProfesional(
                                                profesional.id!);
                                      } else {
                                        await ref
                                            .read(profesionalesNotifierProvider
                                                .notifier)
                                            .reactivarProfesional(
                                                profesional.id!);
                                      }

                                      ref.invalidate(
                                          profesionalesSearchProvider);

                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(profesional.activo
                                                ? 'Profesional dado de baja'
                                                : 'Profesional reactivado'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                                tooltip: profesional.activo
                                    ? 'Dar de baja'
                                    : 'Reactivar',
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(profesionalesSearchProvider),
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
