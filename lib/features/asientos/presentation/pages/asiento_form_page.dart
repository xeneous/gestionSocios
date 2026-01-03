import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/asientos_provider.dart';
import '../../models/asiento_model.dart';
import '../../../cuentas/providers/cuentas_provider.dart';
import '../../../cuentas/models/cuenta_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/cuentas_search_dialog.dart';

class AsientoFormPage extends ConsumerStatefulWidget {
  final int? asiento;
  final int? anioMes;
  final int? tipoAsiento;
  
  const AsientoFormPage({
    super.key,
    this.asiento,
    this.anioMes,
    this.tipoAsiento,
  });

  @override
  ConsumerState<AsientoFormPage> createState() => _AsientoFormPageState();
}

class _AsientoFormPageState extends ConsumerState<AsientoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _fechaController = TextEditingController();
  final _detalleController = TextEditingController();
  
  List<AsientoItemRow> _items = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fechaController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);

    // Listener para habilitar/deshabilitar botón guardar cuando cambia el detalle
    _detalleController.addListener(() {
      setState(() {
        // Trigger rebuild to update button state
      });
    });

    // Si es edición, cargar datos
    if (widget.asiento != null && widget.anioMes != null && widget.tipoAsiento != null) {
      _loadAsientoData();
    } else {
      _addNewItem();
    }
  }

  Future<void> _loadAsientoData() async {
    try {
      final asientoCompleto = await ref.read(asientosNotifierProvider.notifier)
          .getAsientoById(widget.asiento!, widget.anioMes!, widget.tipoAsiento!);
      
      if (asientoCompleto != null && mounted) {
        setState(() {
          _selectedDate = asientoCompleto.header.fecha;
          _fechaController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
          _detalleController.text = asientoCompleto.header.detalle ?? '';
          
          // Cargar items
          _items = asientoCompleto.items.asMap().entries.map((entry) {
            final item = entry.value;
            final row = AsientoItemRow(
              item: entry.key + 1,
              cuentaId: item.cuentaId,
              cuentaDescripcion: item.cuentaDescripcion,
              debe: item.debe,
              haber: item.haber,
              observacion: item.observacion ?? '',
            );
            row.cuentaController.text = item.cuentaNumero?.toString() ?? '';
            row.debeController.text = item.debe > 0 ? item.debe.toStringAsFixed(2) : '';
            row.haberController.text = item.haber > 0 ? item.haber.toStringAsFixed(2) : '';
            row.observacionController.text = item.observacion ?? '';
            return row;
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar asiento: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _detalleController.dispose();
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addNewItem() {
    setState(() {
      _items.add(AsientoItemRow(
        item: _items.length + 1,
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].dispose();
        _items.removeAt(index);
        // Renumerar items
        for (int i = 0; i < _items.length; i++) {
          _items[i].item = i + 1;
        }
      });
    }
  }

  double get _totalDebe {
    return _items.fold(0.0, (sum, item) => sum + item. debe);
  }

  double get _totalHaber {
    return _items.fold(0.0, (sum, item) => sum + item.haber);
  }

  bool get _isBalanced {
    return (_totalDebe - _totalHaber).abs() < 0.01;
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _fechaController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _validateAndSelectAccount(AsientoItemRow item, List<Cuenta> cuentas, String value) {
    final numCuenta = int.tryParse(value);
    if (numCuenta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese un número de cuenta válido'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final cuenta = cuentas.firstWhere(
      (c) => c.cuenta == numCuenta && c.imputable,
      orElse: () => Cuenta(cuenta: 0, descripcion: ''),
    );

    if (cuenta.cuenta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cuenta $numCuenta no existe o no es imputable'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        item.cuentaId = null;
        item.cuentaDescripcion = null;
      });
    } else {
      setState(() {
        item.cuentaId = cuenta.cuenta;
        item.cuentaDescripcion = cuenta.descripcion;
        item.cuentaController.text = cuenta.cuenta.toString();
      });
    }
  }

  Future<void> _showCuentasSearchDialog(AsientoItemRow item) async {
    final selected = await showDialog<Cuenta>(
      context: context,
      builder: (context) => const CuentasSearchDialog(),
    );

    if (selected != null) {
      setState(() {
        item.cuentaId = selected.cuenta;
        item.cuentaDescripcion = selected.descripcion;
        item.cuentaController.text = selected.cuenta.toString();
      });
      item.debeFocus.requestFocus();
    }
  }

  Future<void> _saveAsiento() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Filtrar solo líneas con cuenta seleccionada y monto > 0
    final validItems = _items.where((item) {
      return item.cuentaId != null && (item.debe > 0 || item.haber > 0);
    }).toList();

    // Validar que haya al menos 2 líneas
    if (validItems.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El asiento debe tener al menos 2 líneas con importes'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar balance usando las líneas válidas
    final totalDebe = validItems.fold(0.0, (sum, item) => sum + item.debe);
    final totalHaber = validItems.fold(0.0, (sum, item) => sum + item.haber);
    final isBalanced = (totalDebe - totalHaber).abs() < 0.01;

    if (!isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El asiento no está balanceado. Diferencia: \$${(totalDebe - totalHaber).abs().toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Calcular anio_mes (YYYYMM)
      final anioMes = int.parse(DateFormat('yyyyMM').format(_selectedDate));
      final tipoAsiento = 0; // Tipo 0 = Asiento Diario
      
      final bool isEditing = widget.asiento != null;
      
      // Si es edición, usar el número existente, sino obtener el siguiente
      final asientoNumber = isEditing 
          ? widget.asiento!
          : await ref.read(asientosNotifierProvider.notifier).getNextAsientoNumber(anioMes, tipoAsiento);

      final header = AsientoHeader(
        asiento: asientoNumber,
        anioMes: anioMes,
        tipoAsiento: tipoAsiento,
        fecha: _selectedDate,
        detalle: _detalleController.text.isEmpty ? null : _detalleController.text,
      );

      final items = validItems.asMap().entries.map((entry) => AsientoItem(
        asiento: asientoNumber,
        anioMes: anioMes,
        tipoAsiento: tipoAsiento,
        item: entry.key + 1,
        cuentaId: entry.value.cuentaId!,
        debe: entry.value.debe,
        haber: entry.value.haber,
        observacion: entry.value.observacion.isEmpty ? null : entry.value.observacion,
      )).toList();

      final asientoCompleto = AsientoCompleto(
        header: header,
        items: items,
      );

      if (isEditing) {
        await ref.read(asientosNotifierProvider.notifier).updateAsiento(
          widget.asiento!,
          widget.anioMes!,
          widget.tipoAsiento!,
          asientoCompleto,
        );
      } else {
        await ref.read(asientosNotifierProvider.notifier).createAsiento(asientoCompleto);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Asiento actualizado correctamente' : 'Asiento creado correctamente')),
        );
        context.go('/asientos');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
    final cuentasAsync = ref.watch(cuentasProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.asiento != null ? 'Editar Asiento Contable' : 'Nuevo Asiento Contable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header section
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[100],
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextFormField(
                            controller: _fechaController,
                            decoration: const InputDecoration(
                              labelText: 'Fecha *',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(context),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Campo requerido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _detalleController,
                            decoration: const InputDecoration(
                              labelText: 'Detalle/Glosa',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            maxLength: 255,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Items table
                  Expanded(
                    child: cuentasAsync.when(
                      data: (cuentas) => Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header row
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                                  SizedBox(width: 16),
                                  SizedBox(width: 120, child: Text('Cuenta *', style: TextStyle(fontWeight: FontWeight.bold))),
                                  SizedBox(width: 16),
                                  Expanded(flex: 2, child: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold))),
                                  SizedBox(width: 16),
                                  SizedBox(width: 140, child: Text('Debe', style: TextStyle(fontWeight: FontWeight.bold))),
                                  SizedBox(width: 16),
                                  SizedBox(width: 140, child: Text('Haber', style: TextStyle(fontWeight: FontWeight.bold))),
                                  SizedBox(width: 16),
                                  Expanded(flex: 2, child: Text('Observación', style: TextStyle(fontWeight: FontWeight.bold))),
                                  SizedBox(width: 16),
                                  SizedBox(width: 48, child: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            // Items list
                            Expanded(
                              child: ListView.builder(
                                itemCount: _items.length,
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: Colors.grey[300]!),
                                        right: BorderSide(color: Colors.grey[300]!),
                                        bottom: BorderSide(color: Colors.grey[300]!),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 40,
                                          child: Text('${item.item}'),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 120,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  controller: item.cuentaController,
                                                  focusNode: item.cuentaFocus,
                                                  decoration: const InputDecoration(
                                                    border: OutlineInputBorder(),
                                                    hintText: 'Nro.',
                                                    contentPadding: EdgeInsets.all(8),
                                                    isDense: true,
                                                  ),
                                                  keyboardType: TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.digitsOnly,
                                                  ],
                                                  onFieldSubmitted: (value) {
                                                    _validateAndSelectAccount(item, cuentas, value);
                                                    if (item.cuentaId != null) {
                                                      item.debeFocus.requestFocus();
                                                    }
                                                  },
                                                  onChanged: (value) {
                                                    setState(() {
                                                      item.cuentaId = null;
                                                      item.cuentaDescripcion = null;
                                                    });
                                                  },
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.search, size: 20),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _showCuentasSearchDialog(item),
                                                tooltip: 'Buscar cuenta',
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey[300]!),
                                              borderRadius: BorderRadius.circular(4),
                                              color: Colors.grey[50],
                                            ),
                                            child: Text(
                                              item.cuentaDescripcion ?? '',
                                              style: const TextStyle(fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 140,
                                          child: TextFormField(
                                            controller: item.debeController,
                                            focusNode: item.debeFocus,
                                            enabled: item.haber == 0,
                                            decoration: InputDecoration(
                                              border: const OutlineInputBorder(),
                                              prefix: const Text('\$ '),
                                              contentPadding: const EdgeInsets.all(8),
                                              isDense: true,
                                              fillColor: item.haber > 0 ? Colors.grey[200] : null,
                                              filled: item.haber > 0,
                                            ),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                            ],
                                            onFieldSubmitted: (value) {
                                              if (item.debe > 0) {
                                                item.observacionFocus.requestFocus();
                                              } else {
                                                item.haberFocus.requestFocus();
                                              }
                                            },
                                            onChanged: (value) {
                                              setState(() {
                                                item.debe = double.tryParse(value) ?? 0.0;
                                                if (item.debe > 0) {
                                                  item.haber = 0.0;
                                                  item.haberController.clear();
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 140,
                                          child: TextFormField(
                                            controller: item.haberController,
                                            focusNode: item.haberFocus,
                                            enabled: item.debe == 0,
                                            decoration: InputDecoration(
                                              border: const OutlineInputBorder(),
                                              prefix: const Text('\$ '),
                                              contentPadding: const EdgeInsets.all(8),
                                              isDense: true,
                                              fillColor: item.debe > 0 ? Colors.grey[200] : null,
                                              filled: item.debe > 0,
                                            ),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                            ],
                                            onFieldSubmitted: (value) {
                                              item.observacionFocus.requestFocus();
                                            },
                                            onChanged: (value) {
                                              setState(() {
                                                item.haber = double.tryParse(value) ?? 0.0;
                                                if (item.haber > 0) {
                                                  item.debe = 0.0;
                                                  item.debeController.clear();
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: item.observacionController,
                                            focusNode: item.observacionFocus,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.all(8),
                                              isDense: true,
                                            ),
                                            onFieldSubmitted: (value) {
                                              // Si el asiento no está balanceado, agregar nueva línea
                                              if (!_isBalanced && item.cuentaId != null && (item.debe > 0 || item.haber > 0)) {
                                                _addNewItem();
                                                // Dar foco a la nueva línea
                                                Future.delayed(const Duration(milliseconds: 100), () {
                                                  if (_items.isNotEmpty) {
                                                    _items.last.cuentaFocus.requestFocus();
                                                  }
                                                });
                                              }
                                            },
                                            onChanged: (value) {
                                              item.observacion = value;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 48,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _removeItem(index),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(child: Text('Error: $error')),
                    ),
                  ),
                  // Footer with totals and actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _addNewItem,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar Línea'),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Debe: \$${_totalDebe.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                Text(
                                  'Total Haber: \$${_totalHaber.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      _isBalanced ? Icons.check_circle : Icons.warning,
                                      color: _isBalanced ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isBalanced ? 'Balanceado' : 'No balanceado',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isBalanced ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => context.go('/asientos'),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 16),
                            FilledButton(
                              onPressed: _isLoading || !_isBalanced || _detalleController.text.trim().isEmpty ? null : _saveAsiento,
                              child: const Text('Guardar Asiento'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Helper class para manejar cada fila de item
class AsientoItemRow {
  int item;
  int? cuentaId;
  String? cuentaDescripcion;
  double debe;
  double haber;
  String observacion;
  
  final debeController = TextEditingController();
  final haberController = TextEditingController();
  final observacionController = TextEditingController();
  final cuentaController = TextEditingController();
  
  final cuentaFocus = FocusNode();
  final debeFocus = FocusNode();
  final haberFocus = FocusNode();
  final observacionFocus = FocusNode();

  AsientoItemRow({
    required this.item,
    this.cuentaId,
    this.cuentaDescripcion,
    this.debe = 0.0,
    this.haber = 0.0,
    this.observacion = '',
  });

  void dispose() {
    debeController.dispose();
    haberController.dispose();
    observacionController.dispose();
    cuentaController.dispose();
    cuentaFocus.dispose();
    debeFocus.dispose();
    haberFocus.dispose();
    observacionFocus.dispose();
  }
}
