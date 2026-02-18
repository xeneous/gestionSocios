import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/asiento_model.dart';
import '../../providers/asientos_provider.dart';
import '../../../../core/utils/date_picker_utils.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class AsientosListPage extends ConsumerStatefulWidget {
  const AsientosListPage({super.key});

  @override
  ConsumerState<AsientosListPage> createState() => _AsientosListPageState();
}

class _AsientosListPageState extends ConsumerState<AsientosListPage> {
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  int? _filterTipo;
  int? _asientoDesde;
  int? _asientoHasta;
  bool _hasSearched = false;

  final _asientoDesdeController = TextEditingController();
  final _asientoHastaController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _asientoDesdeController.dispose();
    _asientoHastaController.dispose();
    super.dispose();
  }

  AsientosSearchParams get _searchParams => AsientosSearchParams(
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        tipoAsiento: _filterTipo,
        asientoDesde: _asientoDesde,
        asientoHasta: _asientoHasta,
      );

  Future<void> _pickFechaDesde() async {
    final picked = await pickDate(context, _fechaDesde ?? DateTime.now());
    if (picked != null) setState(() => _fechaDesde = picked);
  }

  Future<void> _pickFechaHasta() async {
    final picked = await pickDate(context, _fechaHasta ?? DateTime.now());
    if (picked != null) setState(() => _fechaHasta = picked);
  }

  void _search() {
    if (_fechaDesde == null && _fechaHasta == null && _asientoDesde == null && _asientoHasta == null && _filterTipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese al menos un filtro para buscar'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _hasSearched = true);
  }

  void _clear() {
    _asientoDesdeController.clear();
    _asientoHastaController.clear();
    setState(() {
      _fechaDesde = null;
      _fechaHasta = null;
      _filterTipo = null;
      _asientoDesde = null;
      _asientoHasta = null;
      _hasSearched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Fila 1: Fechas y Tipo
                Row(
                  children: [
                    // Fecha Desde
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _pickFechaDesde,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha Desde',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _fechaDesde != null
                                ? _dateFormat.format(_fechaDesde!)
                                : 'Seleccionar...',
                            style: TextStyle(
                              color: _fechaDesde != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_fechaDesde != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _fechaDesde = null),
                        tooltip: 'Limpiar fecha desde',
                      ),
                    const SizedBox(width: 8),
                    // Fecha Hasta
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _pickFechaHasta,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha Hasta',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _fechaHasta != null
                                ? _dateFormat.format(_fechaHasta!)
                                : 'Seleccionar...',
                            style: TextStyle(
                              color: _fechaHasta != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_fechaHasta != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _fechaHasta = null),
                        tooltip: 'Limpiar fecha hasta',
                      ),
                    const SizedBox(width: 8),
                    // Tipo de asiento
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<int?>(
                        value: _filterTipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de asiento',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Todos')),
                          DropdownMenuItem(value: 0, child: Text('0 - Diario')),
                          DropdownMenuItem(value: 1, child: Text('1 - Caja Ingresos')),
                          DropdownMenuItem(value: 2, child: Text('2 - Caja Egresos')),
                          DropdownMenuItem(value: 3, child: Text('3 - Compras')),
                          DropdownMenuItem(value: 4, child: Text('4 - Ventas')),
                        ],
                        onChanged: (value) => setState(() => _filterTipo = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Fila 2: Número asiento desde/hasta y botones
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _asientoDesdeController,
                        decoration: const InputDecoration(
                          labelText: 'Nº Asiento Desde',
                          hintText: 'Opcional',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) =>
                            setState(() => _asientoDesde = int.tryParse(value)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _asientoHastaController,
                        decoration: const InputDecoration(
                          labelText: 'Nº Asiento Hasta',
                          hintText: 'Opcional',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) =>
                            setState(() => _asientoHasta = int.tryParse(value)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _search,
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Limpiar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
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
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '${asientos.length} asiento(s) encontrado(s)',
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
                          'Asiento ${header.asiento} - ${_getTipoNombre(header.tipoAsiento)}',
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
                              icon:
                                  const Icon(Icons.delete, color: Colors.red),
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
      BuildContext context, WidgetRef ref, AsientoCompleto asiento) async {
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
