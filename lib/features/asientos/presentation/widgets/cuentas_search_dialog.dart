import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../cuentas/models/cuenta_model.dart';
import '../../../cuentas/providers/cuentas_provider.dart';

class CuentasSearchDialog extends ConsumerStatefulWidget {
  const CuentasSearchDialog({super.key});

  @override
  ConsumerState<CuentasSearchDialog> createState() => _CuentasSearchDialogState();
}

class _CuentasSearchDialogState extends ConsumerState<CuentasSearchDialog> {
  String _searchTerm = '';
  final _searchController = TextEditingController();
  CuentasSearchParams? _currentSearch;

  @override
  void initState() {
    super.initState();
    // Iniciar con búsqueda vacía para cargar primeras cuentas
    _currentSearch = CuentasSearchParams(searchTerm: null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    setState(() {
      _searchTerm = _searchController.text.trim();
      _currentSearch = CuentasSearchParams(
        searchTerm: _searchTerm.isEmpty ? null : _searchTerm,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cuentasAsync = _currentSearch != null
        ? ref.watch(cuentasSearchProvider(_currentSearch!))
        : const AsyncValue<List<Cuenta>>.loading();

    return cuentasAsync.when(
      data: (cuentas) {
        // Filtrar solo cuentas imputables
        final filteredCuentas = cuentas.where((c) => c.imputable).toList();

        return _buildDialog(context, filteredCuentas);
      },
      loading: () => _buildDialog(context, [], isLoading: true),
      error: (error, _) => _buildDialog(context, [], errorMessage: error.toString()),
    );
  }

  Widget _buildDialog(BuildContext context, List<Cuenta> filteredCuentas,
      {bool isLoading = false, String? errorMessage}) {

    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.search, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Buscar Cuenta',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Buscar por número o descripción (presione Enter)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isLoading ? 'Buscando...' : '${filteredCuentas.length} cuenta(s) imputable(s) encontrada(s)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _performSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Error: $errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredCuentas.isEmpty
                      ? const Center(
                          child: Text('No se encontraron cuentas imputables'),
                        )
                  : ListView.builder(
                      itemCount: filteredCuentas.length,
                      itemBuilder: (context, index) {
                        final cuenta = filteredCuentas[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cuenta.cuenta.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            title: Text(cuenta.descripcion),
                            subtitle: cuenta.sigla != null
                                ? Text('Sigla: ${cuenta.sigla}')
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, cuenta),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
