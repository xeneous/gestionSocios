import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../clientes/models/cliente_model.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

/// Página para seleccionar un cliente para iniciar cobranzas
class CobranzasSelectClientePage extends ConsumerStatefulWidget {
  const CobranzasSelectClientePage({super.key});

  @override
  ConsumerState<CobranzasSelectClientePage> createState() =>
      _CobranzasSelectClientePageState();
}

class _CobranzasSelectClientePageState
    extends ConsumerState<CobranzasSelectClientePage> {
  final _codigoController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _cuitController = TextEditingController();
  bool _soloActivos = true;
  List<Cliente> _resultados = [];
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
      final params = ClientesSearchParams(
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

      final clientes = await ref.read(clientesSearchProvider(params).future);

      if (mounted) {
        setState(() {
          _resultados = clientes;
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

  void _selectCliente(Cliente cliente) {
    // Navegar a la página de cobranzas con el cliente seleccionado
    context.go('/cobranzas-clientes/${cliente.codigo}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobranzas Clientes - Seleccionar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/cobranzas-clientes'),
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
                        Icon(Icons.receipt_long, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Seleccione un cliente para registrar cobranzas',
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
                              prefixIcon: Icon(Icons.business),
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
                                : 'Todos los clientes'),
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
                          'Utilice los filtros de arriba para buscar clientes',
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
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No se encontraron clientes'),
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
                '${_resultados.length} cliente(s) encontrado(s)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Haga clic en un cliente para registrar cobranzas',
                style: TextStyle(color: Colors.blue, fontSize: 14),
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        final cliente = _resultados[index - 1];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cliente.esActivo ? Colors.green : Colors.grey,
              child: Text(
                (cliente.razonSocial?.isNotEmpty == true)
                    ? cliente.razonSocial![0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              cliente.nombreCompleto,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cliente.cuit?.isNotEmpty == true)
                  Text('CUIT: ${cliente.cuit}'),
                if (cliente.localidad?.isNotEmpty == true)
                  Text(cliente.localidad!),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!cliente.esActivo)
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
                const Icon(Icons.chevron_right, color: Colors.green),
              ],
            ),
            onTap: () => _selectCliente(cliente),
          ),
        );
      },
    );
  }
}
