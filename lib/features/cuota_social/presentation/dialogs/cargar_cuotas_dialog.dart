import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/valor_cuota_social_model.dart';
import '../../providers/cuota_social_provider.dart';

/// Diálogo para cargar cuotas sociales al crear/editar socio
class CargarCuotasDialog extends ConsumerStatefulWidget {
  final int socioId;
  final bool esResidente;
  final String nombreSocio;
  final String? categoriaResidente;  // R1, R2, R3 - determina descuento

  const CargarCuotasDialog({
    super.key,
    required this.socioId,
    required this.esResidente,
    required this.nombreSocio,
    this.categoriaResidente,
  });

  @override
  ConsumerState<CargarCuotasDialog> createState() => _CargarCuotasDialogState();
}

class _CargarCuotasDialogState extends ConsumerState<CargarCuotasDialog> {
  List<CuotaSocialItem>? _items;
  bool _isLoading = false;
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _cargarItems();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarItems() async {
    setState(() => _isLoading = true);

    try {
      final service = ref.read(cuotaSocialServiceProvider);
      final items = await service.generarItemsCuota(
        esResidente: widget.esResidente,
        cantidadMeses: 3,
        categoriaResidente: widget.categoriaResidente,
      );

      setState(() {
        _items = items;
        // Crear controllers para cada item
        for (var i = 0; i < items.length; i++) {
          _controllers[i] = TextEditingController(
            text: items[i].valor.toStringAsFixed(2),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar valores: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarCuotas() async {
    if (_items == null || _items!.isEmpty) return;

    // Validar que haya al menos una cuota seleccionada
    final itemsSeleccionados = _items!.where((item) => item.incluir).toList();
    if (itemsSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar al menos un mes'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(cuotaSocialServiceProvider);
      await service.crearCuotasSociales(
        socioId: widget.socioId,
        items: _items!,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Retorna true indicando éxito
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear cuotas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cargar Cuotas Sociales'),
                Text(
                  widget.nombreSocio,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _items == null || _items!.isEmpty
                ? const Center(
                    child: Text('No hay cuotas para cargar'),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información del tipo de socio
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.esResidente
                              ? Colors.blue.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.esResidente
                                  ? Icons.school
                                  : Icons.person,
                              color: widget.esResidente
                                  ? Colors.blue
                                  : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.esResidente
                                  ? 'Residente'
                                  : 'Titular/Asociado',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Instrucciones
                      const Text(
                        'Seleccione los meses a cargar y ajuste los valores si es necesario:',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      // Tabla de cuotas
                      _buildTabla(),

                      const SizedBox(height: 16),

                      // Total
                      _buildTotal(),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isLoading || _items == null ? null : _guardarCuotas,
          icon: const Icon(Icons.save),
          label: const Text('Crear Cuotas'),
        ),
      ],
    );
  }

  Widget _buildTabla() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(width: 48), // Checkbox
                Expanded(flex: 2, child: Text('Período', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Valor', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                SizedBox(width: 48), // Botón borrar
              ],
            ),
          ),

          // Rows
          ..._items!.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildRow(index, item);
          }),
        ],
      ),
    );
  }

  Widget _buildRow(int index, CuotaSocialItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          top: index > 0 ? BorderSide(color: Colors.grey.shade200) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 48,
            child: Checkbox(
              value: item.incluir,
              onChanged: (value) {
                setState(() {
                  item.incluir = value ?? false;
                });
              },
            ),
          ),

          // Período
          Expanded(
            flex: 2,
            child: Text(
              item.periodoTexto,
              style: TextStyle(
                color: item.incluir ? Colors.black : Colors.grey,
                fontWeight: item.incluir ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),

          // Valor
          Expanded(
            flex: 1,
            child: TextField(
              controller: _controllers[index],
              enabled: item.incluir,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                prefixText: '\$ ',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final newValue = double.tryParse(value);
                if (newValue != null) {
                  setState(() {
                    item.valor = newValue;
                  });
                }
              },
            ),
          ),

          // Botón borrar
          SizedBox(
            width: 48,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.red,
              onPressed: () {
                setState(() {
                  item.incluir = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotal() {
    final total = _items!
        .where((item) => item.incluir)
        .fold(0.0, (sum, item) => sum + item.valor);

    final cantidad = _items!.where((item) => item.incluir).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total ($cantidad ${cantidad == 1 ? 'mes' : 'meses'}):',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '\$ ${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
