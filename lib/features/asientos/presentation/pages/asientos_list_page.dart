import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/asiento_model.dart';
import '../../providers/asientos_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class AsientosListPage extends ConsumerStatefulWidget {
  const AsientosListPage({super.key});

  @override
  ConsumerState<AsientosListPage> createState() => _AsientosListPageState();
}

class _AsientosListPageState extends ConsumerState<AsientosListPage> {
  String _searchTerm = '';
  int? _filterTipo;
  int? _filterAnioMes;
  int? _filterNumeroAsiento;
  bool _hasSearched = false;

  AsientosSearchParams get _searchParams => AsientosSearchParams(
        anioMes: _filterAnioMes,
        tipoAsiento: _filterTipo,
        numeroAsiento: _filterNumeroAsiento,
        detalle: _searchTerm.isNotEmpty ? _searchTerm : null,
        limit: 20,
      );

  @override
  Widget build(BuildContext context) {
    // Solo hacer la búsqueda si el usuario ha buscado
    final asientosAsync = _hasSearched
        ? ref.watch(asientosSearchProvider(_searchParams))
        : const AsyncValue<List<AsientoCompleto>>.data([]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asientos Contables'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/asientos'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/asientos/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Asiento'),
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Primera fila: Año/Mes, Número de Asiento, Tipo
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Año/Mes (YYYYMM) *',
                          hintText: 'Ej: 202601',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _filterAnioMes = int.tryParse(value);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Nº Asiento',
                          hintText: 'Opcional',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _filterNumeroAsiento = int.tryParse(value);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<int?>(
                        initialValue: _filterTipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de asiento',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Todos')),
                          DropdownMenuItem(value: 0, child: Text('0 - Diario')),
                          DropdownMenuItem(
                              value: 1, child: Text('1 - Caja Ingresos')),
                          DropdownMenuItem(
                              value: 2, child: Text('2 - Caja Egresos')),
                          DropdownMenuItem(value: 3, child: Text('3 - Compras')),
                          DropdownMenuItem(value: 4, child: Text('4 - Ventas')),
                        ],
                        onChanged: (value) {
                          setState(() => _filterTipo = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Segunda fila: Detalle y botones
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Buscar en detalle',
                          hintText: 'Texto del detalle...',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: _searchTerm.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() => _searchTerm = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() => _searchTerm = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_filterAnioMes == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Debe completar el campo Año/Mes para buscar'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _hasSearched = true;
                        });
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchTerm = '';
                          _filterTipo = null;
                          _filterAnioMes = null;
                          _filterNumeroAsiento = null;
                          _hasSearched = false;
                        });
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Limpiar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Results list
          Expanded(
            child: asientosAsync.when(
              data: (asientos) {
                // Mostrar mensaje si no se ha buscado aún
                if (!_hasSearched) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Usa los filtros para buscar asientos',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'La búsqueda está limitada a 20 resultados',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                if (asientos.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No se encontraron asientos'),
                        SizedBox(height: 8),
                        Text('Intenta con otros criterios de búsqueda',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: asientos.length + 1,
                  itemBuilder: (context, index) {
                    // First item: results counter
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '${asientos.length} asiento(s) encontrado(s) (máximo 20)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    final asiento = asientos[index - 1];
                    final header = asiento.header;
                    final dateFormat = DateFormat('dd/MM/yyyy');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              asiento.isBalanced ? Colors.green : Colors.red,
                          child: Icon(
                            asiento.isBalanced ? Icons.check : Icons.warning,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          'Asiento ${header.asiento} - ${_getTipoNombre(header.tipoAsiento)} (${header.anioMes})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fecha: ${dateFormat.format(header.fecha)}'),
                            if (header.detalle != null)
                              Text(header.detalle!,
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${asiento.totalDebe.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                Text(
                                  '\$${asiento.totalHaber.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                context.go(
                                  '/asientos/${header.asiento}/${header.anioMes}/${header.tipoAsiento}',
                                );
                              },
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _confirmDelete(context, ref, asiento),
                              tooltip: 'Eliminar',
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Detalles:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...asiento.items.map((item) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '${item.cuentaNumero} - ${item.cuentaDescripcion ?? ""}',
                                            ),
                                          ),
                                          if (item.debe > 0)
                                            Expanded(
                                              child: Text(
                                                'D: \$${item.debe.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                    color: Colors.red),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          if (item.haber > 0)
                                            Expanded(
                                              child: Text(
                                                'H: \$${item.haber.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                    color: Colors.green),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTipoNombre(int tipo) {
    switch (tipo) {
      case 0:
        return 'Diario';
      case 1:
        return 'Caja Ing.';
      case 2:
        return 'Caja Egr.';
      case 3:
        return 'Compras';
      case 4:
        return 'Ventas';
      default:
        return 'Tipo $tipo';
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, asiento) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Está seguro de eliminar el asiento ${asiento.header.asiento}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(asientosNotifierProvider.notifier).deleteAsiento(
              asiento.header.asiento,
              asiento.header.anioMes,
              asiento.header.tipoAsiento,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Asiento eliminado correctamente')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }
}
