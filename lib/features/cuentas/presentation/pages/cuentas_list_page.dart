import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cuentas_provider.dart';
import '../../models/cuenta_model.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class CuentasListPage extends ConsumerStatefulWidget {
  const CuentasListPage({super.key});

  @override
  ConsumerState<CuentasListPage> createState() => _CuentasListPageState();
}

class _CuentasListPageState extends ConsumerState<CuentasListPage> {
  final _searchController = TextEditingController();
  List<Cuenta> _allCuentas = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // Restaurar búsqueda anterior si existe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedSearch = ref.read(cuentasSearchStateProvider);
      if (savedSearch != null) {
        _searchController.text = savedSearch.searchTerm ?? '';
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final params = CuentasSearchParams(
      searchTerm: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );

    // Guardar búsqueda en el provider
    ref.read(cuentasSearchStateProvider.notifier).setSearch(params);

    // Reset pagination
    setState(() {
      _allCuentas = [];
      _hasMore = true;
    });
  }

  void _clearSearch() {
    _searchController.clear();

    // Limpiar búsqueda del provider
    ref.read(cuentasSearchStateProvider.notifier).clearSearch();

    // Reset pagination
    setState(() {
      _allCuentas = [];
      _hasMore = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSearch = ref.watch(cuentasSearchStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de Cuentas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/cuentas'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/cuentas/nueva'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Cuenta'),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
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
                      'Búsqueda de Cuentas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Buscar cuenta o descripción',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
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
            child: currentSearch == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Utilice el formulario de arriba para buscar cuentas',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildSearchResults(currentSearch),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(CuentasSearchParams currentSearch) {
    final cuentasAsync = ref.watch(cuentasSearchProvider(currentSearch));

    return cuentasAsync.when(
      data: (initialCuentas) {
                // Siempre mostrar los datos más frescos del provider
                // Solo usamos _allCuentas si tiene MÁS de 12 elementos (se cargó "más")
                final cuentasToShow = _allCuentas.length > 12 ? _allCuentas : initialCuentas;

                // Actualizar _allCuentas si está vacío o si solo tiene los primeros 12
                if (_allCuentas.isEmpty || _allCuentas.length <= 12) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _allCuentas = initialCuentas;
                        _hasMore = initialCuentas.length >= 12;
                      });
                    }
                  });
                }

                if (cuentasToShow.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No se encontraron cuentas'),
                        SizedBox(height: 8),
                        Text(
                          'Intenta con otros criterios de búsqueda',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '${cuentasToShow.length} cuenta(s) encontrada(s)',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Cuenta')),
                              DataColumn(label: Text('Corta')),
                              DataColumn(label: Text('Descripción')),
                              DataColumn(label: Text('Sigla')),
                              DataColumn(label: Text('Imputable')),
                              DataColumn(label: Text('Acciones')),
                            ],
                            rows: cuentasToShow.map((cuenta) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(cuenta.cuenta.toString())),
                                  DataCell(Text(cuenta.corta?.toString() ?? '-')),
                                  DataCell(
                                    SizedBox(
                                      width: 300,
                                      child: Text(cuenta.descripcion),
                                    ),
                                  ),
                                  DataCell(Text(cuenta.sigla ?? '-')),
                                  DataCell(
                                    Icon(
                                      cuenta.imputable ? Icons.check : Icons.close,
                                      color: cuenta.imputable ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            context.go('/cuentas/${cuenta.cuenta}');
                                          },
                                          tooltip: 'Editar',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () => _confirmDelete(cuenta),
                                          tooltip: 'Eliminar',
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
                    ),
                    // Botón cargar más
                    if (_hasMore)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _isLoadingMore
                            ? const CircularProgressIndicator()
                            : FilledButton.icon(
                                onPressed: _loadMoreCuentas,
                                icon: const Icon(Icons.expand_more),
                                label: Text('Cargar más (${_allCuentas.length} cargadas)'),
                              ),
                      ),
                    if (!_hasMore && _allCuentas.length >= 12)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Todos los resultados cargados',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                  ],
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
            );
  }

  Future<void> _loadMoreCuentas() async {
    final currentSearch = ref.read(cuentasSearchStateProvider);
    if (_isLoadingMore || !_hasMore || currentSearch == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final moreCuentas = await ref
          .read(cuentasNotifierProvider.notifier)
          .loadMoreCuentas(currentSearch, _allCuentas.length);

      if (mounted) {
        setState(() {
          _allCuentas.addAll(moreCuentas);
          _hasMore = moreCuentas.length >= 12;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar más cuentas: $e')),
        );
      }
    }
  }


  Future<void> _confirmDelete(Cuenta cuenta) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Está seguro de eliminar la cuenta ${cuenta.cuenta} - ${cuenta.descripcion}?',
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

    if (confirmed == true && mounted) {
      try {
        await ref.read(cuentasNotifierProvider.notifier).deleteCuenta(cuenta.cuenta);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuenta eliminada correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }
}
