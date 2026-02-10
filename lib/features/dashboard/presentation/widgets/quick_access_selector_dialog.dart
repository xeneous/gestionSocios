import 'package:flutter/material.dart';
import '../../models/quick_access_item.dart';

class QuickAccessSelectorDialog extends StatefulWidget {
  final List<String> selectedIds;

  const QuickAccessSelectorDialog({
    required this.selectedIds,
    super.key,
  });

  @override
  State<QuickAccessSelectorDialog> createState() =>
      _QuickAccessSelectorDialogState();
}

class _QuickAccessSelectorDialogState extends State<QuickAccessSelectorDialog> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = [...widget.selectedIds];
  }

  @override
  Widget build(BuildContext context) {
    final categories = quickAccessCategories;

    return AlertDialog(
      title: const Text('Personalizar accesos rápidos'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seleccioná los accesos que querés ver en tu pantalla principal.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 16),
              for (final category in categories) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _categoryColor(category),
                      fontSize: 13,
                    ),
                  ),
                ),
                ...allQuickAccessItems
                    .where((item) => item.category == category)
                    .map((item) => CheckboxListTile(
                          dense: true,
                          value: _selected.contains(item.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selected.add(item.id);
                              } else {
                                _selected.remove(item.id);
                              }
                            });
                          },
                          secondary: Icon(item.icon, color: item.color, size: 20),
                          title: Text(item.label, style: const TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                        )),
                const Divider(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Socios':
        return Colors.blue;
      case 'Clientes':
        return Colors.green;
      case 'Proveedores':
        return Colors.orange;
      case 'Contabilidad':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }
}
