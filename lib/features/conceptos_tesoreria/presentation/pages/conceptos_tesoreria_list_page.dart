import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../cuentas_corrientes/providers/conceptos_tesoreria_provider.dart';
import '../../../cuentas_corrientes/models/concepto_tesoreria_model.dart';

/// Página de lista de conceptos de tesorería
class ConceptosTesoreriaListPage extends ConsumerWidget {
  const ConceptosTesoreriaListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conceptosAsync = ref.watch(conceptosTesoreriaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conceptos de Tesorería'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/conceptos-tesoreria/new'),
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
                  Icon(Icons.payment, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay conceptos de tesorería',
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
              return _buildConceptoCard(context, concepto);
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

  Widget _buildConceptoCard(BuildContext context, ConceptoTesoreria concepto) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: concepto.activo ? Colors.green : Colors.grey,
          child: Icon(
            Icons.payment,
            color: Colors.white,
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
            Text('ID: ${concepto.id}'),
            if (concepto.imputacionContable != null)
              Text('Cuenta: ${concepto.imputacionContable}'),
            Row(
              children: [
                if (concepto.esCarteraIngreso)
                  Chip(
                    label: const Text('CI', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.green[100],
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 4),
                if (concepto.esCarteraEgreso)
                  Chip(
                    label: const Text('CE', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.red[100],
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
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => context.go('/conceptos-tesoreria/${concepto.id}'),
        ),
        isThreeLine: true,
      ),
    );
  }
}
