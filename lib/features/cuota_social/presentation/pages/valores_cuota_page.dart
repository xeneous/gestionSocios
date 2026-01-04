import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/valor_cuota_social_model.dart';
import '../../providers/cuota_social_provider.dart';
import '../widgets/valor_cuota_form_dialog.dart';

class ValoresCuotaPage extends ConsumerWidget {
  const ValoresCuotaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valoresAsync = ref.watch(valoresCuotaNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Valores de Cuota Social'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(valoresCuotaNotifierProvider.notifier).refresh();
            },
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: valoresAsync.when(
        data: (valores) => _buildDataTable(context, ref, valores),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(valoresCuotaNotifierProvider.notifier).refresh();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Valor'),
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    WidgetRef ref,
    List<ValorCuotaSocial> valores,
  ) {
    if (valores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay valores configurados',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _mostrarFormulario(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Crear Primer Valor'),
            ),
          ],
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            columns: const [
              DataColumn(label: Text('Período Inicio', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Período Cierre', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Valor Residente', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Valor Titular', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Última Actualización', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: valores.map((valor) {
              return DataRow(
                cells: [
                  DataCell(Text(ValorCuotaSocial.formatAnioMes(valor.anioMesInicio))),
                  DataCell(Text(
                    valor.anioMesCierre != null
                        ? ValorCuotaSocial.formatAnioMes(valor.anioMesCierre!)
                        : 'Actual',
                    style: TextStyle(
                      fontWeight: valor.anioMesCierre == null ? FontWeight.bold : FontWeight.normal,
                      color: valor.anioMesCierre == null ? Colors.green : null,
                    ),
                  )),
                  DataCell(Text(currencyFormat.format(valor.valorResidente))),
                  DataCell(Text(currencyFormat.format(valor.valorTitular))),
                  DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(valor.updatedAt))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Editar',
                          onPressed: () => _mostrarFormulario(context, ref, valor: valor),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmarEliminar(context, ref, valor),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _mostrarFormulario(
    BuildContext context,
    WidgetRef ref, {
    ValorCuotaSocial? valor,
  }) {
    showDialog(
      context: context,
      builder: (context) => ValorCuotaFormDialog(valorExistente: valor),
    );
  }

  void _confirmarEliminar(
    BuildContext context,
    WidgetRef ref,
    ValorCuotaSocial valor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
          '¿Está seguro que desea eliminar el valor de cuota social del período '
          '${ValorCuotaSocial.formatAnioMes(valor.anioMesInicio)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(valoresCuotaNotifierProvider.notifier).eliminar(valor.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Valor eliminado correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
