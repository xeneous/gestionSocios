import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../proveedores/providers/proveedores_provider.dart';
import '../../../proveedores/models/proveedor_model.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

/// Página para seleccionar un proveedor para orden de pago
class OrdenPagoSelectProveedorPage extends ConsumerStatefulWidget {
  const OrdenPagoSelectProveedorPage({super.key});

  @override
  ConsumerState<OrdenPagoSelectProveedorPage> createState() =>
      _OrdenPagoSelectProveedorPageState();
}

class _OrdenPagoSelectProveedorPageState
    extends ConsumerState<OrdenPagoSelectProveedorPage> {
  final _codigoController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _cuitController = TextEditingController();
  bool _soloActivos = true;
  List<Proveedor> _resultados = [];
  bool _hasSearched = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _codigoController.dispose();
    _razonSocialController.dispose();
    _cuitController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final params = ProveedoresSearchParams(
        codigo: _codigoController.text.trim().isEmpty
            ? null
            : int.tryParse(_codigoController.text.trim()),
        razonSocial: _razonSocialController.text.trim().isEmpty
            ? null
            : _razonSocialController.text.trim(),
        cuit: _cuitController.text.trim().isEmpty
            ? null
            : _cuitController.text.trim(),
        soloActivos: _soloActivos,
      );

      final proveedores = await ref.read(proveedoresSearchProvider(params).future);

      if (mounted) {
        setState(() {
          _resultados = proveedores;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en búsqueda: $e')),
        );
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _codigoController.clear();
      _razonSocialController.clear();
      _cuitController.clear();
      _soloActivos = true;
      _resultados = [];
      _hasSearched = false;
    });
  }

  void _selectProveedor(Proveedor proveedor) {
    // Navegar a la página de orden de pago con el proveedor seleccionado
    context.go('/orden-pago/${proveedor.codigo}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orden de Pago - Seleccionar Proveedor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/orden-pago'),
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
                    const Row(
                      children: [
                        Icon(Icons.payment, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Seleccione un proveedor para registrar orden de pago',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
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
                            value: _soloActivos,
                            title: Text(_soloActivos
                                ? 'Solo activos'
                                : 'Todos los proveedores'),
                            subtitle: const Text('Click para cambiar filtro'),
                            onChanged: (value) {
                              setState(() {
                                _soloActivos = value ?? true;
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
            child: !_hasSearched
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Utilice los filtros de arriba para buscar proveedores',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_resultados.isEmpty) {
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
      itemCount: _resultados.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_resultados.length} proveedor(es) encontrado(s)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Haga clic en un proveedor para registrar orden de pago',
                style: TextStyle(color: Colors.orange, fontSize: 14),
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        final proveedor = _resultados[index - 1];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: proveedor.esActivo ? Colors.orange : Colors.grey,
              child: Text(
                (proveedor.razonSocial?.isNotEmpty == true)
                    ? proveedor.razonSocial![0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              proveedor.nombreCompleto,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (proveedor.cuit?.isNotEmpty == true)
                  Text('CUIT: ${proveedor.cuit}'),
                if (proveedor.localidad?.isNotEmpty == true)
                  Text(proveedor.localidad!),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!proveedor.esActivo)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'INACTIVO',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.orange),
              ],
            ),
            onTap: () => _selectProveedor(proveedor),
          ),
        );
      },
    );
  }
}
