import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/socios_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';
import '../../providers/grupos_agrupados_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class SociosListPage extends ConsumerStatefulWidget {
  const SociosListPage({super.key});

  @override
  ConsumerState<SociosListPage> createState() => _SociosListPageState();
}

class _SociosListPageState extends ConsumerState<SociosListPage> {
  final _socioIdController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _nombreController = TextEditingController();
  String? _selectedGrupo;
  bool _soloActivos = true; // true = solo activos, false = todos
  SociosSearchParams? _currentSearch;
  List<dynamic> _allSocios = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void dispose() {
    _socioIdController.dispose();
    _apellidoController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  void _performSearch() {
    setState(() {
      _currentSearch = SociosSearchParams(
        socioId: _socioIdController.text.trim().isEmpty
            ? null
            : int.tryParse(_socioIdController.text.trim()),
        apellido: _apellidoController.text.trim().isEmpty
            ? null
            : _apellidoController.text.trim(),
        nombre: _nombreController.text.trim().isEmpty
            ? null
            : _nombreController.text.trim(),
        grupo: _selectedGrupo,
        soloActivos: _soloActivos, // true = solo grupos activos, false = todos
      );
      // Reset pagination
      _allSocios = [];
      _hasMore = true;
    });
  }

  void _clearSearch() {
    setState(() {
      _socioIdController.clear();
      _apellidoController.clear();
      _nombreController.clear();
      _selectedGrupo = null;
      _soloActivos = true;
      _currentSearch = null;
      // Reset pagination
      _allSocios = [];
      _hasMore = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gruposAsync = ref.watch(gruposAgrupadosProvider(_soloActivos));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Socios'),
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
      drawer: AppDrawer(currentRoute: '/socios'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/socios/nuevo'),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Socio'),
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
                      'Búsqueda de Socios',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _socioIdController,
                            decoration: const InputDecoration(
                              labelText: 'ID Socio',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.tag),
                            ),
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _apellidoController,
                            decoration: const InputDecoration(
                              labelText: 'Apellido',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
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
                              prefixIcon: Icon(Icons.person),
                            ),
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: gruposAsync.when(
                            data: (grupos) => DropdownButtonFormField<String>(
                              initialValue: _selectedGrupo,
                              decoration: const InputDecoration(
                                labelText: 'Grupo',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.group),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Todos'),
                                ),
                                ...grupos.map((g) => DropdownMenuItem(
                                      value: g.codigo,
                                      child: Text(
                                          '${g.codigo} - ${g.descripcion}'),
                                    )),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedGrupo = value);
                              },
                            ),
                            loading: () => const SizedBox(
                              height: 60,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (_, __) =>
                                const Text('Error cargando grupos'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            value: _soloActivos,
                            title: Text(_soloActivos
                                ? 'Solo activos'
                                : 'Todos los socios'),
                            subtitle: const Text('Click para cambiar filtro'),
                            onChanged: (value) {
                              setState(() {
                                _soloActivos = !_soloActivos;
                              });
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
          // Results
          Expanded(
            child: _currentSearch == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Utilice los filtros de arriba para buscar socios',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final sociosAsync = ref.watch(sociosSearchProvider(_currentSearch!));

    return sociosAsync.when(
      data: (initialSocios) {
        // Acumular socios en la primera carga
        if (_allSocios.isEmpty && initialSocios.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _allSocios = initialSocios;
                _hasMore = initialSocios.length >= 12;
              });
            }
          });
        }

        final sociosToShow = _allSocios.isEmpty ? initialSocios : _allSocios;

        if (sociosToShow.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No se encontraron socios'),
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
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sociosToShow.length + 1,
                itemBuilder: (context, index) {
                  // First item: results counter
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sociosToShow.length} socio(s) encontrado(s)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }

                  final socio = sociosToShow[index - 1];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        // Grupo activo: A, H, T, V | Inactivo: B, F, M, R
                        backgroundColor:
                            ['A', 'H', 'T', 'V'].contains(socio.grupo)
                                ? Colors.blue
                                : Colors.grey,
                        child: Text(
                          socio.apellido.isNotEmpty
                              ? socio.apellido[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        socio.nombreCompleto,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ['A', 'H', 'T', 'V'].contains(socio.grupo)
                              ? null
                              : Colors.grey,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (socio.numeroDocumento != null)
                            Text(
                                '${socio.tipoDocumento ?? 'DNI'}: ${socio.numeroDocumento}'),
                          if (socio.email != null && socio.email!.isNotEmpty)
                            Text(socio.email!),
                          if (socio.telefono != null &&
                              socio.telefono!.isNotEmpty)
                            Text('Tel: ${socio.telefono}'),
                          if (socio.grupo != null)
                            Consumer(
                              builder: (context, ref, child) {
                                final gruposAsync =
                                    ref.watch(gruposAgrupadosProvider(false));
                                return gruposAsync.when(
                                  data: (grupos) {
                                    final grupo = grupos
                                        .where((g) => g.codigo == socio.grupo)
                                        .firstOrNull;
                                    return Text(
                                      'Grupo: ${grupo?.descripcion ?? socio.grupo}',
                                      style: TextStyle(color: Colors.blue[700]),
                                    );
                                  },
                                  loading: () => Text('Grupo: ${socio.grupo}',
                                      style:
                                          TextStyle(color: Colors.blue[700])),
                                  error: (_, __) => Text(
                                      'Grupo: ${socio.grupo}',
                                      style:
                                          TextStyle(color: Colors.blue[700])),
                                );
                              },
                            ),
                        ],
                      ),
                      trailing: Consumer(
                        builder: (context, ref, child) {
                          final userRole = ref.watch(userRoleProvider);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!['A', 'H', 'T', 'V'].contains(socio.grupo))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'INACTIVO',
                                    style: TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.account_balance_wallet,
                                    color: Colors.green),
                                onPressed: () {
                                  context
                                      .go('/socios/${socio.id}/cuenta-corriente');
                                },
                                tooltip: 'Cuenta Corriente',
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  context.go('/socios/${socio.id}');
                                },
                                tooltip: 'Editar',
                              ),
                              // Solo administradores pueden eliminar socios
                              if (userRole.esAdministrador)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDelete(context, socio),
                                  tooltip: 'Eliminar',
                                ),
                            ],
                          );
                        },
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
            // Botón cargar más
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isLoadingMore
                    ? const CircularProgressIndicator()
                    : FilledButton.icon(
                        onPressed: _loadMoreSocios,
                        icon: const Icon(Icons.expand_more),
                        label:
                            Text('Cargar más (${_allSocios.length} cargados)'),
                      ),
              ),
            if (!_hasMore && _allSocios.length >= 12)
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

  Future<void> _loadMoreSocios() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final moreSocios = await ref
          .read(sociosNotifierProvider.notifier)
          .loadMoreSocios(_currentSearch!, _allSocios.length);

      if (mounted) {
        setState(() {
          _allSocios.addAll(moreSocios);
          _hasMore = moreSocios.length >= 12;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar más socios: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, socio) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
            '¿Está seguro que desea eliminar al socio ${socio.nombreCompleto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(sociosNotifierProvider.notifier).deleteSocio(socio.id!);
        // Refrescar búsqueda
        _performSearch();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Socio eliminado correctamente')),
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
    }
  }
}
