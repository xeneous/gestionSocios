import 'package:flutter/material.dart';
import '../../models/pais_model.dart';

class PaisesSearchDialog extends StatefulWidget {
  final List<Pais> paises;

  const PaisesSearchDialog({required this.paises, super.key});

  @override
  State<PaisesSearchDialog> createState() => _PaisesSearchDialogState();
}

class _PaisesSearchDialogState extends State<PaisesSearchDialog> {
  String _searchTerm = '';
  final _searchController = TextEditingController();
  int _selectedIndex = -1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Pais> get _filteredPaises {
    List<Pais> result;
    if (_searchTerm.isEmpty) {
      result = widget.paises.take(20).toList();
    } else {
      final searchLower = _searchTerm.toLowerCase();
      result = widget.paises.where((p) {
        return p.nombre.toLowerCase().contains(searchLower);
      }).toList();
    }
    // Ordenar alfabéticamente para que países más usados (Argentina, etc.) estén primero
    result.sort((a, b) => a.nombre.compareTo(b.nombre));
    return result;
  }

  void _selectPais(Pais pais) {
    Navigator.pop(context, pais);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPaises;

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
                const Icon(Icons.public, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Buscar País',
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
                labelText: 'Buscar por nombre',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchTerm = '';
                            _selectedIndex = -1;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchTerm = value;
                  _selectedIndex = -1;
                });
              },
              onSubmitted: (_) {
                if (_selectedIndex >= 0 && _selectedIndex < filtered.length) {
                  _selectPais(filtered[_selectedIndex]);
                } else if (filtered.length == 1) {
                  _selectPais(filtered[0]);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              '${filtered.length} país(es) encontrado(s)',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No se encontraron países'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final pais = filtered[index];
                        final isSelected = index == _selectedIndex;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          color: isSelected ? Colors.blue[50] : null,
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pais.id.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            title: Text(pais.nombre),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectPais(pais),
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
