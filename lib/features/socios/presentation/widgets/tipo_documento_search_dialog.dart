import 'package:flutter/material.dart';
import '../../models/tipo_documento_model.dart';

class TipoDocumentoSearchDialog extends StatefulWidget {
  const TipoDocumentoSearchDialog({super.key});

  @override
  State<TipoDocumentoSearchDialog> createState() => _TipoDocumentoSearchDialogState();
}

class _TipoDocumentoSearchDialogState extends State<TipoDocumentoSearchDialog> {
  String _searchTerm = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TipoDocumento> get _filteredTipos {
    if (_searchTerm.isEmpty) {
      return TipoDocumento.opciones;
    }
    return TipoDocumento.opciones.where((t) {
      final searchLower = _searchTerm.toLowerCase();
      return t.codigo.toLowerCase().contains(searchLower) ||
          t.descripcion.toLowerCase().contains(searchLower);
    }).toList();
  }

  void _selectTipo(TipoDocumento tipo) {
    Navigator.pop(context, tipo);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTipos;

    return Dialog(
      child: Container(
        width: 500,
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.badge, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Buscar Tipo de Documento',
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
                          setState(() => _searchTerm = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchTerm = value);
              },
              onSubmitted: (_) {
                if (filtered.length == 1) {
                  _selectTipo(filtered[0]);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              '${filtered.length} tipo(s) encontrado(s)',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No se encontraron tipos'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final tipo = filtered[index];
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
                                tipo.codigo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            title: Text(tipo.descripcion),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectTipo(tipo),
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
