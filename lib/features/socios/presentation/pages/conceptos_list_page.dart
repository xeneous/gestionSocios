import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/conceptos_provider.dart';
import '../../models/concepto_model.dart';

/// Página de lista de conceptos (socios)
class ConceptosListPage extends ConsumerWidget {
  const ConceptosListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conceptosAsync = ref.watch(conceptosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conceptos de Cuenta Corriente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Ir al inicio',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/conceptos/new'),
            tooltip: 'Nuevo Concepto',
          ),
        ],
      ),
      body: conceptosAsync.when(
        data: (conceptos) {
          if (conceptos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay conceptos registrados',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conceptos.length,
            itemBuilder: (context, index) {
              final concepto = conceptos[index];
              return _buildConceptoCard(context, ref, concepto);
            },
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConceptoCard(
      BuildContext context, WidgetRef ref, Concepto concepto) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: concepto.activo ? Colors.green : Colors.grey,
          child: Text(
            concepto.concepto,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          concepto.descripcion ?? 'Sin descripción',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: concepto.activo ? null : TextDecoration.lineThrough,
            color: concepto.activo ? null : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Código: ${concepto.concepto}'),
            if (concepto.importe != null) Text('Importe: \$${concepto.importe}'),
            Row(
              children: [
                if (concepto.grupo != null)
                  Chip(
                    label: Text('Grupo ${concepto.grupo}',
                        style: const TextStyle(fontSize: 10)),
                    backgroundColor: Colors.blue[100],
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 4),
                if (concepto.modalidad != null)
                  Chip(
                    label: Text('Modalidad ${concepto.modalidad}',
                        style: const TextStyle(fontSize: 10)),
                    backgroundColor: Colors.purple[100],
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 4),
                if (!concepto.activo)
                  const Chip(
                    label: Text('INACTIVO', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: concepto.activo,
              onChanged: (value) async {
                try {
                  await ref
                      .read(conceptosNotifierProvider.notifier)
                      .toggleActivo(concepto.concepto, value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value
                            ? 'Concepto activado'
                            : 'Concepto desactivado'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/conceptos/${concepto.concepto}'),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
