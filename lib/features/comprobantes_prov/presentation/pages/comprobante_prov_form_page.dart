import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/comprobante_prov_model.dart';
import '../../providers/comprobantes_prov_provider.dart';
import '../../providers/orden_pago_provider.dart';
import '../../services/orden_pago_pdf_service.dart';
import '../../../proveedores/providers/proveedores_provider.dart';
import '../../../proveedores/models/proveedor_model.dart';
import '../../../asientos/presentation/widgets/cuentas_search_dialog.dart';
import '../../../cuentas/models/cuenta_model.dart';
import '../../../cuentas_corrientes/providers/conceptos_tesoreria_provider.dart';
import '../../../cuentas_corrientes/models/concepto_tesoreria_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/date_picker_utils.dart';

class ComprobanteProvFormPage extends ConsumerStatefulWidget {
  final int? idTransaccion;
  final int? proveedorId;

  const ComprobanteProvFormPage({
    super.key,
    this.idTransaccion,
    this.proveedorId,
  });

  @override
  ConsumerState<ComprobanteProvFormPage> createState() =>
      _ComprobanteProvFormPageState();
}

class _ComprobanteProvFormPageState
    extends ConsumerState<ComprobanteProvFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;
  CompProvHeader? _comprobante;

  // Controllers para header
  final _proveedorController = TextEditingController();
  final _nroComprobanteController = TextEditingController();
  final _descripcionController = TextEditingController();

  // Valores del header
  DateTime _fecha = DateTime.now();
  DateTime _fechaReal = DateTime.now();
  DateTime? _fecha1Venc;
  DateTime? _fecha2Venc;
  int? _tipoComprobante;
  String? _tipoFactura;

  // Items
  List<CompProvItem> _items = [];
  int? _cuentaProveedor; // Cuenta contable habitual del proveedor seleccionado

  // Validación de proveedor
  Proveedor? _proveedorSeleccionado;
  bool _buscandoProveedor = false;
  bool _proveedorValidado = false;

  // Pago inmediato
  bool _pagarAlGuardar = false;
  final Map<int, double> _formasPago = {};
  final Map<int, TextEditingController> _formasPagoControllers = {};

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  bool get isEditing => widget.idTransaccion != null;

  @override
  void initState() {
    super.initState();
    _proveedorController.addListener(_onProveedorCodigoChanged);
    if (isEditing) {
      _loadComprobante();
    } else {
      if (widget.proveedorId != null) {
        _proveedorController.text = widget.proveedorId.toString();
        Future.microtask(
            () => _validarYCargarProveedor(widget.proveedorId.toString()));
      }
      _isLoadingData = false;
    }
  }

  @override
  void dispose() {
    _proveedorController.removeListener(_onProveedorCodigoChanged);
    _proveedorController.dispose();
    _nroComprobanteController.dispose();
    _descripcionController.dispose();
    for (var controller in _formasPagoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onProveedorCodigoChanged() {
    final codigoActual = _proveedorController.text.trim();
    if (_proveedorSeleccionado != null &&
        codigoActual != _proveedorSeleccionado!.codigo.toString()) {
      setState(() {
        _proveedorSeleccionado = null;
        _proveedorValidado = false;
        _cuentaProveedor = null;
      });
    }
  }

  Future<void> _loadComprobante() async {
    try {
      final comprobante =
          await ref.read(comprobanteProvProvider(widget.idTransaccion!).future);

      // Cargar datos del proveedor si el comprobante existe
      Proveedor? proveedor;
      if (comprobante != null) {
        proveedor =
            await ref.read(proveedorProvider(comprobante.proveedor).future);
      }

      if (comprobante != null && mounted) {
        setState(() {
          _comprobante = comprobante;
          _proveedorController.text = comprobante.proveedor.toString();
          _proveedorSeleccionado = proveedor;
          _proveedorValidado = true;
          _cuentaProveedor = proveedor?.cuenta;
          _nroComprobanteController.text = comprobante.nroComprobante;
          _descripcionController.text = comprobante.descripcionImporte ?? '';
          _fecha = comprobante.fecha;
          _fechaReal = comprobante.fechaReal;
          _fecha1Venc = comprobante.fecha1Venc;
          _fecha2Venc = comprobante.fecha2Venc;
          _tipoComprobante = comprobante.tipoComprobante;
          _tipoFactura = comprobante.tipoFactura;
          _items = comprobante.items ?? [];
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando comprobante: $e')),
        );
      }
    }
  }

  Future<void> _validarYCargarProveedor(String codigo) async {
    final parsedCodigo = int.tryParse(codigo.trim());
    if (parsedCodigo == null) {
      if (mounted && codigo.trim().isNotEmpty) {
        setState(() {
          _proveedorSeleccionado = null;
          _proveedorValidado = true;
          _buscandoProveedor = false;
          _cuentaProveedor = null;
        });
      }
      return;
    }

    if (mounted) setState(() => _buscandoProveedor = true);

    try {
      final proveedor =
          await ref.read(proveedorProvider(parsedCodigo).future);
      if (mounted) {
        setState(() {
          _proveedorSeleccionado = proveedor;
          _cuentaProveedor = proveedor?.cuenta;
          _buscandoProveedor = false;
          _proveedorValidado = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _proveedorSeleccionado = null;
          _buscandoProveedor = false;
          _proveedorValidado = true;
          _cuentaProveedor = null;
        });
      }
    }
  }

  int _getAnioMes(DateTime fecha) {
    return fecha.year * 100 + fecha.month;
  }

  double _calcularTotal() {
    return _items.fold(0, (sum, item) => sum + item.importe);
  }

  Future<void> _saveComprobante() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tipoComprobante == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debe seleccionar un tipo de comprobante')),
      );
      return;
    }

    final proveedorId = int.tryParse(_proveedorController.text.trim());
    if (proveedorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de proveedor inválido')),
      );
      return;
    }

    if (_proveedorSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Proveedor no encontrado. Verifique el código.')),
      );
      return;
    }

    // Validar pago inmediato
    if (_pagarAlGuardar) {
      if (_formasPago.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Seleccione al menos una forma de pago')),
        );
        return;
      }
      final diferencia = (_calcularTotal() - _getTotalFormasPago()).abs();
      if (diferencia >= 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'El total de formas de pago debe coincidir con el importe')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final header = CompProvHeader(
        idTransaccion: _comprobante?.idTransaccion,
        comprobante: _comprobante?.comprobante ?? 0,
        anioMes: _getAnioMes(_fecha),
        fecha: _fecha,
        proveedor: proveedorId,
        tipoComprobante: _tipoComprobante!,
        nroComprobante: _nroComprobanteController.text.trim(),
        tipoFactura: _tipoFactura,
        totalImporte: _calcularTotal(),
        cancelado: _comprobante?.cancelado ?? 0,
        fecha1Venc: _fecha1Venc,
        fecha2Venc: _fecha2Venc,
        estado: 'P', // Estado siempre es P (Pendiente)
        fechaReal: _fechaReal,
        descripcionImporte: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
      );

      print('📋 FORMULARIO - Header creado con estado: ${header.estado}');
      print('📋 FORMULARIO - Header.toJson(): ${header.toJson()}');

      final notifier = ref.read(comprobantesProvNotifierProvider.notifier);

      if (isEditing) {
        await notifier.actualizarComprobante(header, _items);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Comprobante actualizado correctamente')),
          );
          context.go('/comprobantes-proveedores');
        }
      } else {
        // Crear comprobante
        final comprobanteCreado =
            await notifier.crearComprobante(header, _items);

        // Si tiene pago inmediato, generar la OP
        if (_pagarAlGuardar) {
          try {
            // Crear mapa de transacciones a pagar (solo esta factura)
            final transaccionesAPagar = {
              comprobanteCreado.idTransaccion!: comprobanteCreado.totalImporte,
            };

            // Generar la orden de pago
            final opNotifier = ref.read(ordenPagoNotifierProvider.notifier);
            final resultadoOP = await opNotifier.generarOrdenPago(
              proveedorId: proveedorId,
              transaccionesAPagar: transaccionesAPagar,
              formasPago: _formasPago,
            );

            if (mounted) {
              final numeroOP = resultadoOP['numero_orden_pago'];
              final idTransaccionOP = resultadoOP['id_transaccion'] as int;

              // Mostrar diálogo de éxito con opción de imprimir
              await showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      SizedBox(width: 8),
                      Text('Operación Exitosa'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Factura Nro. ${comprobanteCreado.nroComprobante}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Orden de Pago Nro. $numeroOP',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                          'Total: ${_currencyFormat.format(comprobanteCreado.totalImporte)}'),
                      const SizedBox(height: 8),
                      const Text('La factura ha sido registrada y pagada.'),
                    ],
                  ),
                  actions: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await _imprimirOrdenPago(idTransaccionOP);
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimir OP'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Aceptar'),
                    ),
                  ],
                ),
              );
              context.go('/comprobantes-proveedores');
            }
          } catch (e) {
            // La factura se creó pero falló la OP
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Factura creada, pero error al generar OP: $e'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
              context.go('/comprobantes-proveedores');
            }
          }
        } else {
          // Sin pago inmediato
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comprobante creado correctamente')),
            );
            context.go('/comprobantes-proveedores');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        if (errorStr.contains('ASIENTO_WARNING:')) {
          // El comprobante fue guardado pero falló la generación del asiento
          final warning = errorStr
              .split('ASIENTO_WARNING:')
              .last
              .replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Comprobante guardado. Advertencia en asiento contable: $warning',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 8),
            ),
          );
          context.go('/comprobantes-proveedores');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorStr'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectFecha(String tipo) async {
    DateTime initialDate;
    switch (tipo) {
      case 'fecha':
        initialDate = _fecha;
        break;
      case 'fechaReal':
        initialDate = _fechaReal;
        break;
      case 'fecha1Venc':
        initialDate = _fecha1Venc ?? DateTime.now();
        break;
      case 'fecha2Venc':
        initialDate = _fecha2Venc ?? DateTime.now();
        break;
      default:
        return;
    }

    final fecha = await pickDate(context, initialDate);

    if (fecha != null) {
      setState(() {
        switch (tipo) {
          case 'fecha':
            _fecha = fecha;
            break;
          case 'fechaReal':
            _fechaReal = fecha;
            break;
          case 'fecha1Venc':
            _fecha1Venc = fecha;
            break;
          case 'fecha2Venc':
            _fecha2Venc = fecha;
            break;
        }
      });
    }
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _ItemDialog(
        tipoComprobante: _tipoComprobante,
        cuentaProveedor: _cuentaProveedor,
        onSave: (item) {
          setState(() {
            _items.add(item);
          });
        },
      ),
    );
  }

  void _editItem(int index) {
    showDialog(
      context: context,
      builder: (context) => _ItemDialog(
        item: _items[index],
        tipoComprobante: _tipoComprobante,
        cuentaProveedor: _cuentaProveedor,
        onSave: (item) {
          setState(() {
            _items[index] = item;
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _buscarProveedor() async {
    final result = await showDialog<Proveedor>(
      context: context,
      builder: (context) => const _ProveedorSearchDialog(),
    );

    if (result != null) {
      setState(() {
        _proveedorController.text = result.codigo.toString();
        _cuentaProveedor = result.cuenta;
        _proveedorSeleccionado = result;
        _proveedorValidado = true;
      });
    }
  }

  double _getTotalFormasPago() {
    return _formasPago.values.fold(0.0, (sum, monto) => sum + monto);
  }

  Future<void> _imprimirOrdenPago(int idTransaccion) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generando PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final supabase = ref.read(supabaseProvider);
      final pdfService = OrdenPagoPdfService(supabase);
      final pdf =
          await pdfService.generarOrdenPagoPdf(idTransaccion: idTransaccion);

      if (mounted) Navigator.pop(context);

      await pdfService.imprimirOrdenPago(pdf);
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al imprimir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addFormaPago(ConceptoTesoreria concepto) {
    setState(() {
      if (!_formasPago.containsKey(concepto.id)) {
        final saldoRestante = _calcularTotal() - _getTotalFormasPago();
        _formasPago[concepto.id] = saldoRestante > 0 ? saldoRestante : 0.0;
      }
    });
  }

  Widget _buildPagoInmediatoCard() {
    final conceptosAsync = ref.watch(conceptosCarteraEgresoProvider);
    final total = _calcularTotal();
    final totalFormasPago = _getTotalFormasPago();
    final diferencia = (total - totalFormasPago).abs();

    return Card(
      color: _pagarAlGuardar ? Colors.green[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _pagarAlGuardar ? Icons.payments : Icons.payment_outlined,
                  color: _pagarAlGuardar ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pago Inmediato',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _pagarAlGuardar,
                  onChanged: _items.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _pagarAlGuardar = value;
                            if (!value) {
                              _formasPago.clear();
                            }
                          });
                        },
                ),
              ],
            ),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Agregue items al comprobante para habilitar el pago inmediato',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            if (_pagarAlGuardar) ...[
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Total a pagar: ${_currencyFormat.format(total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    'Formas de pago: ${_currencyFormat.format(totalFormasPago)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: diferencia < 0.01 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              conceptosAsync.when(
                data: (conceptos) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lista de formas de pago disponibles
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: conceptos.map((concepto) {
                          final isSelected =
                              _formasPago.containsKey(concepto.id);
                          return FilterChip(
                            label: Text(concepto.descripcion ?? ''),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                _addFormaPago(concepto);
                              } else {
                                setState(() {
                                  _formasPago.remove(concepto.id);
                                  _formasPagoControllers
                                      .remove(concepto.id)
                                      ?.dispose();
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      if (_formasPago.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        // Campos de monto para cada forma de pago seleccionada
                        ...conceptos
                            .where((c) => _formasPago.containsKey(c.id))
                            .map((concepto) {
                          if (!_formasPagoControllers
                              .containsKey(concepto.id)) {
                            _formasPagoControllers[concepto.id] =
                                TextEditingController(
                              text:
                                  _formasPago[concepto.id]?.toStringAsFixed(2),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(concepto.descripcion ?? ''),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller:
                                        _formasPagoControllers[concepto.id],
                                    decoration: const InputDecoration(
                                      prefixText: '\$ ',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final monto = double.tryParse(value);
                                      if (monto != null && monto >= 0) {
                                        setState(() {
                                          _formasPago[concepto.id] = monto;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _formasPago.remove(concepto.id);
                                      _formasPagoControllers
                                          .remove(concepto.id)
                                          ?.dispose();
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error cargando formas de pago'),
              ),
              if (_formasPago.isNotEmpty && diferencia >= 0.01)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'La suma de las formas de pago debe coincidir con el total',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiposAsync = ref.watch(tiposComprobanteCompraProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Comprobante' : 'Nuevo Comprobante'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/comprobantes-proveedores'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Datos del comprobante
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Datos del Comprobante',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _proveedorController,
                                    decoration: InputDecoration(
                                      labelText: 'Código Proveedor *',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.store),
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_buscandoProveedor)
                                            const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              ),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.search),
                                            tooltip: 'Buscar proveedor',
                                            onPressed: _buscarProveedor,
                                          ),
                                        ],
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onFieldSubmitted: _validarYCargarProveedor,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Ingrese el código del proveedor';
                                      }
                                      if (int.tryParse(value.trim()) == null) {
                                        return 'Código inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: tiposAsync.when(
                                    data: (tipos) {
                                      // Verificar si el valor actual está en la lista
                                      final valorValido =
                                          _tipoComprobante != null &&
                                              tipos.any((t) =>
                                                  t.codigo == _tipoComprobante);
                                      return DropdownButtonFormField<int?>(
                                        initialValue: valorValido
                                            ? _tipoComprobante
                                            : null,
                                        decoration: const InputDecoration(
                                          labelText: 'Tipo Comprobante *',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.category),
                                        ),
                                        items: tipos
                                            .map((tipo) =>
                                                DropdownMenuItem<int?>(
                                                  value: tipo.codigo,
                                                  child: Text(tipo.descripcion),
                                                ))
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _tipoComprobante = value;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null) {
                                            return 'Seleccione tipo';
                                          }
                                          return null;
                                        },
                                      );
                                    },
                                    loading: () => const TextField(
                                      enabled: false,
                                      decoration: InputDecoration(
                                        labelText: 'Cargando...',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    error: (_, __) => const TextField(
                                      enabled: false,
                                      decoration: InputDecoration(
                                        labelText: 'Error',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Mostrar razon social del proveedor validado
                            if (_proveedorSeleccionado != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: Colors.green, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _proveedorSeleccionado!.nombreCompleto,
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_proveedorValidado &&
                                _proveedorController.text.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.red[700], size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Proveedor no encontrado',
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _nroComprobanteController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nro. Comprobante *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.receipt),
                                      hintText: 'XXXX-XXXXXXXX',
                                    ),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Ingrese el número';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    initialValue: _tipoFactura,
                                    decoration: const InputDecoration(
                                      labelText: 'Tipo Factura',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.description),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: null, child: Text('--')),
                                      DropdownMenuItem(
                                          value: 'A', child: Text('A')),
                                      DropdownMenuItem(
                                          value: 'B', child: Text('B')),
                                      DropdownMenuItem(
                                          value: 'C', child: Text('C')),
                                      DropdownMenuItem(
                                          value: 'M', child: Text('M')),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _tipoFactura = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fechas
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fechas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectFecha('fecha'),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Fecha Comprobante *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.calendar_today),
                                      ),
                                      child: Text(_dateFormat.format(_fecha)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectFecha('fechaReal'),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Fecha Contable *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.calendar_month),
                                      ),
                                      child:
                                          Text(_dateFormat.format(_fechaReal)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectFecha('fecha1Venc'),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: '1er Vencimiento',
                                        border: const OutlineInputBorder(),
                                        prefixIcon:
                                            const Icon(Icons.event_available),
                                        suffixIcon: _fecha1Venc != null
                                            ? IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  setState(() {
                                                    _fecha1Venc = null;
                                                  });
                                                },
                                              )
                                            : null,
                                      ),
                                      child: Text(_fecha1Venc != null
                                          ? _dateFormat.format(_fecha1Venc!)
                                          : ''),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectFecha('fecha2Venc'),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: '2do Vencimiento',
                                        border: const OutlineInputBorder(),
                                        prefixIcon:
                                            const Icon(Icons.event_busy),
                                        suffixIcon: _fecha2Venc != null
                                            ? IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  setState(() {
                                                    _fecha2Venc = null;
                                                  });
                                                },
                                              )
                                            : null,
                                      ),
                                      child: Text(_fecha2Venc != null
                                          ? _dateFormat.format(_fecha2Venc!)
                                          : ''),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Descripción',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descripcionController,
                              decoration: const InputDecoration(
                                labelText: 'Descripción / Observaciones',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.notes),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Items',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _addItem,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Agregar Item'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_items.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text(
                                    'No hay items agregados',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _items.length,
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  return Card(
                                    color: Colors.grey[50],
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text('${index + 1}'),
                                      ),
                                      title: Text(
                                        'Concepto: ${item.concepto} - Cuenta: ${item.cuenta}',
                                      ),
                                      subtitle: Text(
                                        'Importe: ${_currencyFormat.format(item.importe)} | Alícuota: ${item.alicuota}%',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () => _editItem(index),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () => _removeItem(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Total: ${_currencyFormat.format(_calcularTotal())}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Opción de pago inmediato (solo para nuevos comprobantes)
                    if (!isEditing) _buildPagoInmediatoCard(),
                    const SizedBox(height: 24),

                    // Botones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              context.go('/comprobantes-proveedores'),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _saveComprobante,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(isEditing ? 'Actualizar' : 'Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Diálogo para agregar/editar items
class _ItemDialog extends ConsumerStatefulWidget {
  final CompProvItem? item;
  final int? tipoComprobante;
  final int? cuentaProveedor;
  final Function(CompProvItem) onSave;

  const _ItemDialog({
    this.item,
    this.tipoComprobante,
    this.cuentaProveedor,
    required this.onSave,
  });

  @override
  ConsumerState<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<_ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cuentaController = TextEditingController();
  final _importeController = TextEditingController();
  final _baseContableController = TextEditingController();
  final _alicuotaController = TextEditingController();
  final _detalleController = TextEditingController();

  String? _selectedConcepto;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _selectedConcepto = widget.item!.concepto.trim();
      _cuentaController.text = widget.item!.cuenta.toString();
      _importeController.text = widget.item!.importe.toString();
      _baseContableController.text = widget.item!.baseContable.toString();
      _alicuotaController.text = widget.item!.alicuota.toString();
      _detalleController.text = widget.item!.detalle ?? '';
    } else {
      _baseContableController.text = '0';
      _alicuotaController.text = '0';
      // Pre-llenar cuenta con la cuenta habitual del proveedor
      if (widget.cuentaProveedor != null) {
        _cuentaController.text = widget.cuentaProveedor.toString();
      }
    }
  }

  @override
  void dispose() {
    _cuentaController.dispose();
    _importeController.dispose();
    _baseContableController.dispose();
    _alicuotaController.dispose();
    _detalleController.dispose();
    super.dispose();
  }

  Future<void> _buscarCuenta() async {
    final result = await showDialog<Cuenta>(
      context: context,
      builder: (context) => const CuentasSearchDialog(),
    );
    if (result != null) {
      setState(() {
        _cuentaController.text = result.cuenta.toString();
      });
    }
  }

  Widget _buildConceptoField(List<String> conceptos) {
    // Si hay conceptos disponibles para el tipo seleccionado, mostrar dropdown
    if (conceptos.isNotEmpty) {
      // Asegurarse que el valor seleccionado sea válido dentro de la lista
      final valorValido =
          _selectedConcepto != null && conceptos.contains(_selectedConcepto);

      return DropdownButtonFormField<String>(
        value: valorValido ? _selectedConcepto : null,
        decoration: const InputDecoration(
          labelText: 'Concepto *',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.category),
        ),
        items: conceptos
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (value) => setState(() => _selectedConcepto = value),
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? 'Requerido' : null,
      );
    }

    // Fallback: campo de texto libre, con 'EXE' como sugerencia por defecto
    _selectedConcepto ??= 'EXE';
    return TextFormField(
      initialValue: _selectedConcepto,
      decoration: InputDecoration(
        labelText: 'Concepto *',
        border: const OutlineInputBorder(),
        helperText: widget.tipoComprobante == null
            ? 'Seleccione el tipo de comprobante primero'
            : 'Sin conceptos configurados para este tipo',
      ),
      maxLength: 5,
      textCapitalization: TextCapitalization.characters,
      onChanged: (value) => _selectedConcepto = value.trim().toUpperCase(),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Requerido' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cargar conceptos del tipo de comprobante seleccionado
    final conceptosAsync = widget.tipoComprobante != null
        ? ref.watch(conceptosPorTipoProvider(widget.tipoComprobante!))
        : const AsyncValue<List<String>>.data([]);

    return AlertDialog(
      title: Text(widget.item != null ? 'Editar Item' : 'Agregar Item'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: conceptosAsync.when(
                        data: _buildConceptoField,
                        loading: () => const TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Cargando conceptos...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        error: (_, __) => _buildConceptoField([]),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _cuentaController,
                        decoration: InputDecoration(
                          labelText: 'Cuenta *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            tooltip: 'Buscar cuenta',
                            onPressed: _buscarCuenta,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requerido';
                          }
                          if (int.tryParse(value.trim()) == null) {
                            return 'Número inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _importeController,
                        decoration: const InputDecoration(
                          labelText: 'Importe *',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requerido';
                          }
                          if (double.tryParse(value.trim()) == null) {
                            return 'Número inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _alicuotaController,
                        decoration: const InputDecoration(
                          labelText: 'Alícuota',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _baseContableController,
                  decoration: const InputDecoration(
                    labelText: 'Base Contable',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _detalleController,
                  decoration: const InputDecoration(
                    labelText: 'Detalle',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final item = CompProvItem(
                idCampo: widget.item?.idCampo,
                idTransaccion: widget.item?.idTransaccion,
                comprobante: widget.item?.comprobante ?? 0,
                anioMes: widget.item?.anioMes ?? 0,
                item: widget.item?.item ?? 0,
                concepto: (_selectedConcepto ?? '').toUpperCase(),
                cuenta: int.parse(_cuentaController.text.trim()),
                importe: double.parse(_importeController.text.trim()),
                baseContable:
                    double.tryParse(_baseContableController.text.trim()) ?? 0,
                alicuota:
                    double.tryParse(_alicuotaController.text.trim()) ?? 0,
                detalle: _detalleController.text.trim().isEmpty
                    ? null
                    : _detalleController.text.trim(),
              );
              widget.onSave(item);
              Navigator.pop(context);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// Diálogo para buscar proveedores
class _ProveedorSearchDialog extends ConsumerStatefulWidget {
  const _ProveedorSearchDialog();

  @override
  ConsumerState<_ProveedorSearchDialog> createState() =>
      _ProveedorSearchDialogState();
}

class _ProveedorSearchDialogState
    extends ConsumerState<_ProveedorSearchDialog> {
  final _searchController = TextEditingController();
  List<Proveedor> _resultados = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final params = ProveedoresSearchParams(
        razonSocial: query,
        soloActivos: true,
      );
      final proveedores =
          await ref.read(proveedoresSearchProvider(params).future);

      if (mounted) {
        setState(() {
          _resultados = proveedores;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.store, color: Colors.orange),
          SizedBox(width: 8),
          Text('Buscar Proveedor'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Razón Social',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _buscar,
                ),
              ),
              onSubmitted: (_) => _buscar(),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: !_hasSearched
                  ? const Center(
                      child: Text(
                        'Ingrese un texto para buscar',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _resultados.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron proveedores',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _resultados.length,
                              itemBuilder: (context, index) {
                                final proveedor = _resultados[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.orange,
                                    child: Text(
                                      proveedor.codigo?.toString() ?? '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(proveedor.nombreCompleto),
                                  subtitle: Text([
                                    if (proveedor.codigo != null)
                                      'Cód: ${proveedor.codigo}',
                                    if (proveedor.cuit?.isNotEmpty == true)
                                      'CUIT: ${proveedor.cuit}',
                                  ].join('  |  ')),
                                  onTap: () =>
                                      Navigator.pop(context, proveedor),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
