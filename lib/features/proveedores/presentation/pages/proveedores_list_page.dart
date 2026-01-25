import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/proveedores_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class ProveedoresListPage extends ConsumerStatefulWidget {
  const ProveedoresListPage({super.key});

  @override
  ConsumerState<ProveedoresListPage> createState() => _ProveedoresListPageState();
}

class _ProveedoresListPageState extends ConsumerState<ProveedoresListPage> {
  final _codigoController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _cuitController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _codigoController.dispose();
    _razonSocialController.dispose();
    _cuitController.dispose();
    super.dispose();
  }

  void _syncControllersFromState(ProveedoresSearchState searchState) {
    if (!_initialized) {
      _codigoController.text = searchState.codigo;
      _razonSocialController.text = searchState.razonSocial;
      _cuitController.text = searchState.cuit;
      _initialized = true;
    }
  }

  Future<void> _performSearch() async {
    final notifier = ref.read(proveedoresSearchStateProvider.notifier);

    notifier.updateCodigo(_codigoController.text.trim());
    notifier.updateRazonSocial(_razonSocialController.text.trim());
    notifier.updateCuit(_cuitController.text.trim());

    notifier.clearResults();

    final searchState = ref.read(proveedoresSearchStateProvider);

    try {
      final proveedores = await ref.read(
          proveedoresSearchProvider(searchState.toSearchParams()).future);
      notifier.setResultados(proveedores);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en búsqueda: $e')),
        );
      }
    }
  }

  void _clearSearch() {
    _codigoController.clear();
    _razonSocialController.clear();
    _cuitController.clear();
    ref.read(proveedoresSearchStateProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(proveedoresSearchStateProvider);

    _syncControllersFromState(searchState);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proveedores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/proveedores'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/proveedores/nuevo'),
        icon: const Icon(Icons.add_business),
        label: const Text('Nuevo Proveedor'),
      ),
      body: Column(
        children: [
          // Formulario de búsqueda
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
                      'Búsqueda de Proveedores',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _codigoController,
                            decoration: const InputDecoration(
                              labelText: 'Código',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.tag),
                            ),
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _razonSocialController,
                            decoration: const InputDecoration(
                              labelText: 'Razón Social',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.store),
                            ),
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _cuitController,
                            decoration: const InputDecoration(
                              labelText: 'CUIT',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.credit_card),
                            ),
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            value: searchState.soloActivos,
                            title: Text(searchState.soloActivos
                                ? 'Solo activos'
                                : 'Todos los proveedores'),
                            subtitle: const Text('Click para cambiar filtro'),
                            onChanged: (value) {
                              ref.read(proveedoresSearchStateProvider.notifier)
                                  .updateSoloActivos(value ?? true);
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _performSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Resultados
          Expanded(
            child: !searchState.hasSearched
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Utilice los filtros para buscar proveedores',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildSearchResults(searchState),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ProveedoresSearchState searchState) {
    final proveedores = searchState.resultados;

    if (proveedores.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No se encontraron proveedores'),
            SizedBox(height: 8),
            Text(
              'Intenta con otros criterios de búsqueda',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: proveedores.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${proveedores.length} proveedor(es) encontrado(s)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        final proveedor = proveedores[index - 1];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: proveedor.esActivo ? Colors.orange : Colors.grey,
              child: const Icon(Icons.store, color: Colors.white),
            ),
            title: Text(
              proveedor.nombreCompleto,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: proveedor.esActivo ? null : Colors.grey,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (proveedor.cuit != null && proveedor.cuit!.isNotEmpty)
                  Text('CUIT: ${proveedor.cuit}'),
                if (proveedor.mail != null && proveedor.mail!.isNotEmpty)
                  Text(proveedor.mail!),
                if (proveedor.telefono1 != null && proveedor.telefono1!.isNotEmpty)
                  Text('Tel: ${proveedor.telefono1}'),
                if (proveedor.localidad != null && proveedor.localidad!.isNotEmpty)
                  Text(proveedor.localidad!),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!proveedor.esActivo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'INACTIVO',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                  onPressed: () {
                    context.go('/proveedores/${proveedor.codigo}/cuenta-corriente');
                  },
                  tooltip: 'Cuenta Corriente',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    context.go('/proveedores/${proveedor.codigo}');
                  },
                  tooltip: 'Editar',
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
