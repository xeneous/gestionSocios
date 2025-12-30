import 'package:flutter/material.dart';
import '../../models/provincia_model.dart';

class ProvinciasSearchDialog extends StatefulWidget {
  final List<Provincia> provincias;

  const ProvinciasSearchDialog({required this.provincias, super.key});

  @override
  State<ProvinciasSearchDialog> createState() => _ProvinciasSearchDialogState();
}

class _ProvinciasSearchDialogState extends State<ProvinciasSearchDialog> {
  String _searchTerm = '';
  final _searchController = TextEditingController();
  int _selectedIndex = -1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Provincia> get _filteredProvincias {
    List<Provincia> result;
    if (_searchTerm.isEmpty) {
      result = widget.provincias;
    } else {
      final searchLower = _searchTerm.toLowerCase();
      result = widget.provincias.where((p) {
        return p.nombre.toLowerCase().contains(searchLower);
      }).toList();
    }
    // Ordenar alfabéticamente
    result.sort((a, b) => a.nombre.compareTo(b.nombre));
    return result;
  }

  void _selectProvincia(Provincia provincia) {
    Navigator.pop(context, provincia);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProvincias;

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
                const Icon(Icons.location_on, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Buscar Provincia',
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
                  _selectProvincia(filtered[_selectedIndex]);
                } else if (filtered.length == 1) {
                  _selectProvincia(filtered[0]);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              '${filtered.length} provincia(s) encontrada(s)',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No se encontraron provincias'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final provincia = filtered[index];
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
                                provincia.id.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            title: Text(provincia.nombre),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectProvincia(provincia),
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
