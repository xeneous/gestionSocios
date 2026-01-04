import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../socios/models/concepto_model.dart';
import '../../../socios/providers/conceptos_provider.dart';

class DetalleItemRowData {
  String? concepto;
  String? conceptoDescripcion;
  double cantidad;
  double importe;

  DetalleItemRowData({
    this.concepto,
    this.conceptoDescripcion,
    this.cantidad = 1.0,
    this.importe = 0.0,
  });

  double get importeTotal => cantidad * importe;
}

class DetalleItemRow extends ConsumerStatefulWidget {
  final int itemNumber;
  final DetalleItemRowData data;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const DetalleItemRow({
    required super.key,
    required this.itemNumber,
    required this.data,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  ConsumerState<DetalleItemRow> createState() => _DetalleItemRowState();
}

class _DetalleItemRowState extends ConsumerState<DetalleItemRow> {
  late TextEditingController _cantidadController;
  late TextEditingController _importeController;

  @override
  void initState() {
    super.initState();
    _cantidadController = TextEditingController(
      text: widget.data.cantidad.toString(),
    );
    _importeController = TextEditingController(
      text: widget.data.importe > 0
          ? widget.data.importe.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _importeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Item ${widget.itemNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onRemove,
                  tooltip: 'Eliminar item',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Concepto
            InkWell(
              onTap: () async {
                try {
                  final conceptos = await ref.read(conceptosProvider.future);

                  if (context.mounted) {
                    final concepto = await showDialog<Concepto>(
                      context: context,
                      builder: (context) => _ConceptoSearchDialog(
                        conceptos: conceptos,
                      ),
                    );

                    if (concepto != null) {
                      setState(() {
                        widget.data.concepto = concepto.concepto;
                        widget.data.conceptoDescripcion = concepto.descripcion;

                        // Pre-rellenar importe si existe
                        if (concepto.importe != null) {
                          widget.data.importe = concepto.importe!;
                          _importeController.text =
                              concepto.importe!.toStringAsFixed(2);
                        }
                      });
                      widget.onChanged();
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al cargar conceptos: $e')),
                    );
                  }
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Concepto *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.search),
                ),
                child: Text(
                  widget.data.concepto != null
                      ? '${widget.data.concepto} - ${widget.data.conceptoDescripcion}'
                      : 'Seleccionar concepto...',
                  style: TextStyle(
                    color: widget.data.concepto != null
                        ? Colors.black
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cantidad + Importe
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _cantidadController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      widget.data.cantidad = double.tryParse(value) ?? 1.0;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _importeController,
                    decoration: const InputDecoration(
                      labelText: 'Importe Unitario *',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      widget.data.importe = double.tryParse(value) ?? 0.0;
                      widget.onChanged();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Inválido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Total',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      '\$${widget.data.importeTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptoSearchDialog extends StatefulWidget {
  final List<Concepto> conceptos;

  const _ConceptoSearchDialog({required this.conceptos});

  @override
  State<_ConceptoSearchDialog> createState() => _ConceptoSearchDialogState();
}

class _ConceptoSearchDialogState extends State<_ConceptoSearchDialog> {
  final _searchController = TextEditingController();
  List<Concepto> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.conceptos;
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.conceptos;
      } else {
        _filtered = widget.conceptos
            .where((c) =>
                c.concepto.toLowerCase().contains(query.toLowerCase()) ||
                (c.descripcion?.toLowerCase() ?? '').contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar Concepto'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final concepto = _filtered[index];
                  return ListTile(
                    title: Text(concepto.descripcion ?? ''),
                    subtitle: Text(
                      '${concepto.concepto} - '
                      '${concepto.importe != null ? '\$${concepto.importe!.toStringAsFixed(2)}' : 'Sin importe'}',
                    ),
                    onTap: () => Navigator.pop(context, concepto),
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
