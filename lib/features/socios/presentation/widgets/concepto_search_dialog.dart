import 'package:flutter/material.dart';
import '../../models/concepto_model.dart';

class ConceptoSearchDialog extends StatefulWidget {
  final List<Concepto> conceptos;

  const ConceptoSearchDialog({required this.conceptos, super.key});

  @override
  State<ConceptoSearchDialog> createState() => _ConceptoSearchDialogState();
}

class _ConceptoSearchDialogState extends State<ConceptoSearchDialog> {
  String _searchTerm = '';
  final _searchController = TextEditingController();
  int _selectedIndex = -1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Concepto> get _filteredConceptos {
    if (_searchTerm.isEmpty) {
      return widget.conceptos;
    }
    final searchLower = _searchTerm.toLowerCase();
    return widget.conceptos.where((c) {
      return c.concepto.toLowerCase().contains(searchLower) ||
          c.descripcion.toLowerCase().contains(searchLower);
    }).toList();
  }

  void _selectConcepto(Concepto concepto) {
    Navigator.pop(context, concepto);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredConceptos;

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
                const Icon(Icons.receipt_long, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Buscar Concepto',
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
                labelText: 'Buscar por código o descripción',
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
                  _selectConcepto(filtered[_selectedIndex]);
                } else if (filtered.length == 1) {
                  _selectConcepto(filtered[0]);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              '${filtered.length} concepto(s) encontrado(s)',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No se encontraron conceptos'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final concepto = filtered[index];
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
                                concepto.concepto,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(concepto.descripcion),
                            subtitle: concepto.importe != null
                                ? Text('Importe: \$${concepto.importe!.toStringAsFixed(2)}')
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectConcepto(concepto),
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
