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
import '../../../cuentas_corrientes/providers/conceptos_tesoreria_provider.dart';
import '../../../cuentas_corrientes/models/concepto_tesoreria_model.dart';
import '../../../asientos/presentation/widgets/cuentas_search_dialog.dart';
import '../../../cuentas/models/cuenta_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/date_picker_utils.dart';

/// Pantalla unificada para ingresar factura y pagarla en el mismo momento
class PagoDirectoPage extends ConsumerStatefulWidget {
  const PagoDirectoPage({super.key});

  @override
  ConsumerState<PagoDirectoPage> createState() => _PagoDirectoPageState();
}

class _PagoDirectoPageState extends ConsumerState<PagoDirectoPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Datos del proveedor
  final _proveedorController = TextEditingController();
  Proveedor? _proveedorSeleccionado;

  // Datos del comprobante
  final _nroComprobanteController = TextEditingController();
  final _importeController = TextEditingController();
  final _cuentaController = TextEditingController();
  final _descripcionController = TextEditingController();

  DateTime _fecha = DateTime.now();
  DateTime? _fecha1Venc;
  int? _tipoComprobante;
  String? _tipoFactura;

  // Formas de pago
  final Map<int, double> _formasPago = {};
  final Map<int, TextEditingController> _formasPagoControllers = {};

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  @override
  void dispose() {
    _proveedorController.dispose();
    _nroComprobanteController.dispose();
    _importeController.dispose();
    _cuentaController.dispose();
    _descripcionController.dispose();
    for (var controller in _formasPagoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _getImporte() {
    return double.tryParse(_importeController.text.trim()) ?? 0.0;
  }

  double _getTotalFormasPago() {
    return _formasPago.values.fold(0.0, (sum, monto) => sum + monto);
  }

  void _addFormaPago(ConceptoTesoreria concepto) {
    setState(() {
      if (!_formasPago.containsKey(concepto.id)) {
        final saldoRestante = _getImporte() - _getTotalFormasPago();
        _formasPago[concepto.id] = saldoRestante > 0 ? saldoRestante : 0.0;
      }
    });
  }

  Future<void> _selectFecha(bool isVencimiento) async {
    final fecha = await pickDate(context, isVencimiento ? (_fecha1Venc ?? DateTime.now()) : _fecha);

    if (fecha != null) {
      setState(() {
        if (isVencimiento) {
          _fecha1Venc = fecha;
        } else {
          _fecha = fecha;
        }
      });
    }
  }

  Future<void> _buscarProveedor() async {
    final result = await showDialog<Proveedor>(
      context: context,
      builder: (context) => const _ProveedorSearchDialog(),
    );

    if (result != null) {
      setState(() {
        _proveedorSeleccionado = result;
        _proveedorController.text = result.codigo.toString();
      });
    }
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

  bool _canProcesar() {
    final importe = _getImporte();
    final totalFormasPago = _getTotalFormasPago();
    return importe > 0 &&
        _formasPago.isNotEmpty &&
        (importe - totalFormasPago).abs() < 0.01;
  }

  Future<void> _procesarPago() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tipoComprobante == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un tipo de comprobante')),
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

    if (_formasPago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione al menos una forma de pago')),
      );
      return;
    }

    final diferencia = (_getImporte() - _getTotalFormasPago()).abs();
    if (diferencia >= 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'El total de formas de pago debe coincidir con el importe')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Mostrar diálogo de carga
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
                Text('Procesando pago...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final importe = _getImporte();
      final cuenta = int.parse(_cuentaController.text.trim());
      final anioMes = _fecha.year * 100 + _fecha.month;

      // 1. Crear la factura
      final header = CompProvHeader(
        comprobante: 0,
        anioMes: anioMes,
        fecha: _fecha,
        proveedor: proveedorId,
        tipoComprobante: _tipoComprobante!,
        nroComprobante: _nroComprobanteController.text.trim(),
        tipoFactura: _tipoFactura,
        totalImporte: importe,
        cancelado: 0,
        fecha1Venc: _fecha1Venc,
        estado: 'P',
        fechaReal: _fecha,
        descripcionImporte: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
      );

      final item = CompProvItem(
        comprobante: 0,
        anioMes: anioMes,
        item: 1,
        concepto: 'GTO',
        cuenta: cuenta,
        importe: importe,
        baseContable: importe,
        alicuota: 0,
      );

      final compNotifier = ref.read(comprobantesProvNotifierProvider.notifier);
      final comprobanteCreado =
          await compNotifier.crearComprobante(header, [item]);

      // 2. Crear la orden de pago
      final transaccionesAPagar = {
        comprobanteCreado.idTransaccion!: comprobanteCreado.totalImporte,
      };

      final opNotifier = ref.read(ordenPagoNotifierProvider.notifier);
      final resultadoOP = await opNotifier.generarOrdenPago(
        proveedorId: proveedorId,
        transaccionesAPagar: transaccionesAPagar,
        formasPago: _formasPago,
      );

      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      final numeroOP = resultadoOP['numero_orden_pago'];
      final idTransaccionOP = resultadoOP['id_transaccion'] as int;
      final asientoError = resultadoOP['asiento_error'] as String?;

      // Mostrar advertencia si el asiento falló
      if (asientoError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Advertencia: OP generada pero falló el asiento contable: $asientoError'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
          ),
        );
      }

      // Mostrar diálogo de éxito
      if (mounted) {
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 8),
                Text('Pago Procesado'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Factura: ${comprobanteCreado.nroComprobante}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Orden de Pago Nro. $numeroOP',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Total: ${_currencyFormat.format(importe)}'),
                const SizedBox(height: 8),
                Text(
                  'Proveedor: ${_proveedorSeleccionado?.razonSocial ?? "ID $proveedorId"}',
                ),
                const SizedBox(height: 16),
                const Text(
                  'La factura ha sido registrada y pagada exitosamente.',
                  style: TextStyle(color: Colors.grey),
                ),
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
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // Limpiar formulario para nuevo pago
                  _limpiarFormulario();
                },
                child: const Text('Nuevo Pago'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.go('/');
                },
                child: const Text('Ir al Inicio'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _limpiarFormulario() {
    setState(() {
      _proveedorController.clear();
      _proveedorSeleccionado = null;
      _nroComprobanteController.clear();
      _importeController.clear();
      _cuentaController.clear();
      _descripcionController.clear();
      _fecha = DateTime.now();
      _fecha1Venc = null;
      _tipoComprobante = null;
      _tipoFactura = null;
      _formasPago.clear();
      for (var controller in _formasPagoControllers.values) {
        controller.dispose();
      }
      _formasPagoControllers.clear();
    });
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

  @override
  Widget build(BuildContext context) {
    final tiposAsync = ref.watch(tiposComprobanteCompraProvider);
    final conceptosAsync = ref.watch(conceptosCarteraEgresoProvider);
    final importe = _getImporte();
    final totalFormasPago = _getTotalFormasPago();
    final diferencia = (importe - totalFormasPago).abs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago Directo a Proveedor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _limpiarFormulario,
            tooltip: 'Limpiar formulario',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel izquierdo: Datos de la factura
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado
                    Card(
                      color: Colors.orange[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                color: Colors.orange, size: 32),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ingreso y Pago de Factura',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Complete los datos de la factura y seleccione las formas de pago',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Proveedor
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Proveedor',
                              style: TextStyle(
                                fontSize: 16,
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
                                      labelText: 'Código *',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.store),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.search),
                                        onPressed: _buscarProveedor,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value?.trim().isEmpty == true) {
                                        return 'Requerido';
                                      }
                                      if (int.tryParse(value!.trim()) == null) {
                                        return 'Inválido';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      // Limpiar proveedor seleccionado si cambia el código
                                      if (_proveedorSeleccionado != null &&
                                          _proveedorSeleccionado!.codigo
                                                  .toString() !=
                                              value.trim()) {
                                        setState(() {
                                          _proveedorSeleccionado = null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _proveedorSeleccionado?.razonSocial ??
                                          'Seleccione un proveedor',
                                      style: TextStyle(
                                        color: _proveedorSeleccionado != null
                                            ? Colors.black
                                            : Colors.grey,
                                        fontWeight:
                                            _proveedorSeleccionado != null
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: tiposAsync.when(
                                    data: (tipos) {
                                      final tiposFactura = tipos
                                          .where((t) => t.multiplicador == 1)
                                          .toList();
                                      return DropdownButtonFormField<int?>(
                                        initialValue: _tipoComprobante,
                                        decoration: const InputDecoration(
                                          labelText: 'Tipo *',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: tiposFactura
                                            .map((tipo) =>
                                                DropdownMenuItem<int?>(
                                                  value: tipo.codigo,
                                                  child: Text(tipo.descripcion),
                                                ))
                                            .toList(),
                                        onChanged: (value) {
                                          setState(
                                              () => _tipoComprobante = value);
                                        },
                                        validator: (value) =>
                                            value == null ? 'Requerido' : null,
                                      );
                                    },
                                    loading: () =>
                                        const LinearProgressIndicator(),
                                    error: (_, __) =>
                                        const Text('Error cargando tipos'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _nroComprobanteController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nro. Comprobante *',
                                      border: OutlineInputBorder(),
                                      hintText: 'XXXX-XXXXXXXX',
                                    ),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    validator: (value) =>
                                        value?.trim().isEmpty == true
                                            ? 'Requerido'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    initialValue: _tipoFactura,
                                    decoration: const InputDecoration(
                                      labelText: 'Letra',
                                      border: OutlineInputBorder(),
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
                                    ],
                                    onChanged: (value) {
                                      setState(() => _tipoFactura = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectFecha(false),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Fecha *',
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
                                    onTap: () => _selectFecha(true),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Vencimiento',
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(Icons.event),
                                        suffixIcon: _fecha1Venc != null
                                            ? IconButton(
                                                icon: const Icon(Icons.clear,
                                                    size: 18),
                                                onPressed: () {
                                                  setState(
                                                      () => _fecha1Venc = null);
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
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _importeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Importe Total *',
                                      border: OutlineInputBorder(),
                                      prefixText: '\$ ',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    validator: (value) {
                                      if (value?.trim().isEmpty == true) {
                                        return 'Requerido';
                                      }
                                      if (double.tryParse(value!.trim()) ==
                                          null) {
                                        return 'Número inválido';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cuentaController,
                                    decoration: InputDecoration(
                                      labelText: 'Cuenta Contable *',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.search),
                                        onPressed: _buscarCuenta,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value?.trim().isEmpty == true) {
                                        return 'Requerido';
                                      }
                                      if (int.tryParse(value!.trim()) == null) {
                                        return 'Número inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descripcionController,
                              decoration: const InputDecoration(
                                labelText: 'Descripción / Observaciones',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Divisor vertical
            const VerticalDivider(width: 1),

            // Panel derecho: Formas de pago
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.grey[50],
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.green[100],
                      child: Row(
                        children: [
                          const Icon(Icons.payment, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            'Formas de Pago',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Resumen
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Importe Factura:'),
                              Text(
                                _currencyFormat.format(importe),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Formas de Pago:'),
                              Text(
                                _currencyFormat.format(totalFormasPago),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: diferencia < 0.01
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          if (diferencia >= 0.01 && importe > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Diferencia:'),
                                Text(
                                  _currencyFormat
                                      .format(importe - totalFormasPago),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Lista de conceptos disponibles
                    Expanded(
                      child: conceptosAsync.when(
                        data: (conceptos) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Wrap(
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
                              ),
                              if (_formasPago.isNotEmpty) ...[
                                const Divider(),
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.all(12),
                                    children: conceptos
                                        .where((c) =>
                                            _formasPago.containsKey(c.id))
                                        .map((concepto) {
                                      if (!_formasPagoControllers
                                          .containsKey(concepto.id)) {
                                        _formasPagoControllers[concepto.id] =
                                            TextEditingController(
                                          text: _formasPago[concepto.id]
                                              ?.toStringAsFixed(2),
                                        );
                                      }
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                concepto.descripcion ?? '',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ),
                                            Expanded(
                                              child: TextField(
                                                controller:
                                                    _formasPagoControllers[
                                                        concepto.id],
                                                decoration:
                                                    const InputDecoration(
                                                  prefixText: '\$ ',
                                                  isDense: true,
                                                  border: OutlineInputBorder(),
                                                ),
                                                keyboardType:
                                                    TextInputType.number,
                                                onChanged: (value) {
                                                  final monto =
                                                      double.tryParse(value);
                                                  if (monto != null &&
                                                      monto >= 0) {
                                                    setState(() {
                                                      _formasPago[concepto.id] =
                                                          monto;
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
                                                  _formasPago
                                                      .remove(concepto.id);
                                                  _formasPagoControllers
                                                      .remove(concepto.id)
                                                      ?.dispose();
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const Center(
                            child: Text('Error cargando conceptos')),
                      ),
                    ),

                    // Botón de procesar
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: _isLoading || !_canProcesar()
                            ? null
                            : _procesarPago,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('PROCESAR PAGO'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para buscar proveedores
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
                                      proveedor.codigo.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(proveedor.nombreCompleto),
                                  subtitle: proveedor.cuit?.isNotEmpty == true
                                      ? Text('CUIT: ${proveedor.cuit}')
                                      : null,
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
