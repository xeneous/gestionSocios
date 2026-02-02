import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/cobranzas_clientes_provider.dart';
import '../../services/recibo_cliente_pdf_service.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../cuentas_corrientes/providers/conceptos_tesoreria_provider.dart';
import '../../../cuentas_corrientes/models/concepto_tesoreria_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Página principal de cobranzas de clientes con selección múltiple
class CobranzasClientePage extends ConsumerStatefulWidget {
  final int clienteId;

  const CobranzasClientePage({
    super.key,
    required this.clienteId,
  });

  @override
  ConsumerState<CobranzasClientePage> createState() => _CobranzasClientePageState();
}

class _CobranzasClientePageState extends ConsumerState<CobranzasClientePage> {
  // Mapa de IDs de transacciones seleccionadas con sus importes a pagar
  final Map<int, double> _selectedPagos = {};

  // Formas de pago seleccionadas
  final Map<int, double> _formasPago = {}; // conceptoId -> monto

  // Controllers para campos de formas de pago
  final Map<int, TextEditingController> _formasPagoControllers = {};

  // Controllers para campos de pagos parciales
  final Map<int, TextEditingController> _pagosControllers = {};

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  @override
  void dispose() {
    for (var controller in _formasPagoControllers.values) {
      controller.dispose();
    }
    for (var controller in _pagosControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clienteAsync = ref.watch(clienteProvider(widget.clienteId));
    final saldoAsync = ref.watch(saldoClienteProvider(widget.clienteId));
    final pendientesAsync = ref.watch(comprobantesPendientesClienteProvider(widget.clienteId));

    return Scaffold(
      appBar: AppBar(
        title: clienteAsync.when(
          data: (cliente) => Text('Cobranzas - ${cliente?.razonSocial ?? "Cliente"}'),
          loading: () => const Text('Cobranzas'),
          error: (_, __) => const Text('Cobranzas'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cobranzas-clientes'),
        ),
        actions: [
          if (_selectedPagos.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Center(
                child: Chip(
                  label: Text(
                    '${_selectedPagos.length} seleccionados - ${_currencyFormat.format(_getTotalSeleccionado())}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.green,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Información del cliente y saldos
          _buildInfoHeader(clienteAsync, saldoAsync),
          const Divider(height: 1),

          // Tabla de movimientos pendientes
          Expanded(
            flex: 2,
            child: _buildMovimientosPendientes(pendientesAsync),
          ),

          const Divider(height: 2, thickness: 2),

          // Panel de formas de pago y acciones
          Expanded(
            flex: 1,
            child: _buildFormasPagoPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHeader(
    AsyncValue clienteAsync,
    AsyncValue<Map<String, double>> saldoAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.green[50],
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.green, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: clienteAsync.when(
              data: (cliente) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cliente?.codigo} - ${cliente?.razonSocial}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (cliente?.cuit?.isNotEmpty == true)
                    Text(
                      'CUIT: ${cliente!.cuit}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error cargando cliente'),
            ),
          ),
          saldoAsync.when(
            data: (saldo) {
              final saldoTotal = saldo['saldo_total'] ?? 0.0;
              final isDeudor = saldoTotal > 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Saldo a Cobrar: ${_currencyFormat.format(saldoTotal)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDeudor ? Colors.red : Colors.green,
                    ),
                  ),
                  Text(
                    '${saldo['total_transacciones']?.toInt() ?? 0} comprobantes',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('Error'),
          ),
        ],
      ),
    );
  }

  Widget _buildMovimientosPendientes(
    AsyncValue<List<Map<String, dynamic>>> pendientesAsync,
  ) {
    return pendientesAsync.when(
      data: (comprobantes) {
        if (comprobantes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green[300]),
                const SizedBox(height: 16),
                const Text(
                  'No hay comprobantes pendientes de cobro',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header con instrucciones
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Seleccione los comprobantes a cobrar e ingrese el monto para cada uno',
                      style: TextStyle(fontSize: 14, color: Colors.blue),
                    ),
                  ),
                  if (_selectedPagos.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Limpiar selección'),
                    ),
                ],
              ),
            ),
            // Tabla de movimientos
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                    columns: const [
                      DataColumn(
                          label: Text('Sel.',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Fecha',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Tipo',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Nro. Comprobante',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Vencimiento',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Importe',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                      DataColumn(
                          label: Text('Cancelado',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                      DataColumn(
                          label: Text('Saldo',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                      DataColumn(
                          label: Text('A Cobrar',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                    ],
                    rows: _buildRows(comprobantes),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
          ],
        ),
      ),
    );
  }

  List<DataRow> _buildRows(List<Map<String, dynamic>> comprobantes) {
    final rows = <DataRow>[];

    for (final comp in comprobantes) {
      final idTransaccion = comp['id_transaccion'] as int;
      final totalImporte = (comp['total_importe'] as num).toDouble();
      final cancelado = (comp['cancelado'] as num?)?.toDouble() ?? 0;
      final saldoPendiente = totalImporte - cancelado;
      final isSelected = _selectedPagos.containsKey(idTransaccion);

      final tipoData = comp['tip_vent_mod_header'] as Map<String, dynamic>?;
      final tipoDesc = tipoData != null
          ? '${tipoData['comprobante']} - ${tipoData['descripcion']}'
          : 'Tipo ${comp['tipo_comprobante']}';

      rows.add(
        DataRow(
          selected: isSelected,
          color: WidgetStateProperty.all(
              isSelected ? Colors.green[50] : Colors.orange[50]),
          cells: [
            DataCell(
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedPagos[idTransaccion] = saldoPendiente;
                    } else {
                      _selectedPagos.remove(idTransaccion);
                    }
                  });
                },
              ),
            ),
            DataCell(
              Text(_dateFormat.format(DateTime.parse(comp['fecha']))),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tipoDesc),
                  if (comp['tipo_factura'] != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        comp['tipo_factura'],
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            DataCell(Text(comp['nro_comprobante'] ?? 'S/N')),
            DataCell(
              Text(comp['fecha1_venc'] != null
                  ? _dateFormat.format(DateTime.parse(comp['fecha1_venc']))
                  : '-'),
            ),
            DataCell(Text(_currencyFormat.format(totalImporte))),
            DataCell(
              Text(
                _currencyFormat.format(cancelado),
                style: const TextStyle(color: Colors.green),
              ),
            ),
            DataCell(
              Text(
                _currencyFormat.format(saldoPendiente),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
            DataCell(
              isSelected
                  ? SizedBox(
                      width: 100,
                      child: Builder(
                        builder: (context) {
                          if (!_pagosControllers.containsKey(idTransaccion)) {
                            _pagosControllers[idTransaccion] = TextEditingController(
                              text: _selectedPagos[idTransaccion]?.toStringAsFixed(2),
                            );
                          }

                          return TextField(
                            decoration: const InputDecoration(
                              prefixText: '\$',
                              isDense: true,
                              contentPadding: EdgeInsets.all(8),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            controller: _pagosControllers[idTransaccion],
                            onChanged: (value) {
                              final monto = double.tryParse(value);
                              if (monto != null &&
                                  monto > 0 &&
                                  monto <= saldoPendiente) {
                                setState(() {
                                  _selectedPagos[idTransaccion] = monto;
                                });
                              }
                            },
                          );
                        },
                      ),
                    )
                  : const Text('-'),
            ),
          ],
        ),
      );
    }

    return rows;
  }

  Widget _buildFormasPagoPanel() {
    final conceptosAsync = ref.watch(conceptosCarteraIngresoProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Formas de Pago',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Total a Cobrar: ${_currencyFormat.format(_getTotalSeleccionado())}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Total Formas de Pago: ${_currencyFormat.format(_getTotalFormasPago())}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getTotalFormasPago() == _getTotalSeleccionado()
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: conceptosAsync.when(
              data: (conceptos) {
                if (_selectedPagos.isEmpty) {
                  return const Center(
                    child: Text(
                      'Seleccione comprobantes pendientes para agregar formas de pago',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return Row(
                  children: [
                    // Lista de formas de pago disponibles
                    Expanded(
                      flex: 2,
                      child: Card(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.blue[50],
                              child: const Row(
                                children: [
                                  Icon(Icons.payment, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Formas de Pago Disponibles',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: conceptos.length,
                                itemBuilder: (context, index) {
                                  final concepto = conceptos[index];
                                  return ListTile(
                                    title: Text(concepto.descripcion ?? ''),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.add_circle,
                                          color: Colors.green),
                                      onPressed: () => _addFormaPago(concepto),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Formas de pago seleccionadas
                    Expanded(
                      flex: 3,
                      child: Card(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.green[50],
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.green),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Formas de Pago Seleccionadas',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  if (_formasPago.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() => _formasPago.clear());
                                      },
                                      icon: const Icon(Icons.clear, size: 18),
                                      label: const Text('Limpiar'),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _formasPago.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Agregue formas de pago',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _formasPago.length,
                                      itemBuilder: (context, index) {
                                        final conceptoId =
                                            _formasPago.keys.elementAt(index);
                                        final monto = _formasPago[conceptoId]!;
                                        final concepto = conceptos
                                            .where((c) => c.id == conceptoId)
                                            .firstOrNull;

                                        if (!_formasPagoControllers.containsKey(conceptoId)) {
                                          _formasPagoControllers[conceptoId] = TextEditingController(
                                            text: monto.toStringAsFixed(2),
                                          );
                                        }

                                        return ListTile(
                                          title: Text(
                                              concepto?.descripcion ?? ''),
                                          subtitle: SizedBox(
                                            width: 150,
                                            child: TextField(
                                              decoration: const InputDecoration(
                                                prefixText: '\$',
                                                isDense: true,
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                              controller: _formasPagoControllers[conceptoId],
                                              onChanged: (value) {
                                                final newMonto =
                                                    double.tryParse(value);
                                                if (newMonto != null &&
                                                    newMonto > 0) {
                                                  setState(() {
                                                    _formasPago[conceptoId] =
                                                        newMonto;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () {
                                              setState(() {
                                                _formasPago.remove(conceptoId);
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            // Botón de generar recibo
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: FilledButton.icon(
                                onPressed: _canGenerateRecibo()
                                    ? _generarRecibo
                                    : null,
                                icon: const Icon(Icons.receipt),
                                label: const Text('Generar Recibo'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  double _getTotalSeleccionado() {
    return _selectedPagos.values.fold(0.0, (sum, monto) => sum + monto);
  }

  double _getTotalFormasPago() {
    return _formasPago.values.fold(0.0, (sum, monto) => sum + monto);
  }

  bool _canGenerateRecibo() {
    return _selectedPagos.isNotEmpty &&
        _formasPago.isNotEmpty &&
        (_getTotalFormasPago() - _getTotalSeleccionado()).abs() < 0.01;
  }

  void _clearSelection() {
    setState(() {
      _selectedPagos.clear();
      _formasPago.clear();
    });
  }

  void _addFormaPago(ConceptoTesoreria concepto) {
    setState(() {
      if (!_formasPago.containsKey(concepto.id)) {
        final saldoRestante = _getTotalSeleccionado() - _getTotalFormasPago();
        _formasPago[concepto.id] = saldoRestante > 0 ? saldoRestante : 0.0;
      }
    });
  }

  Future<void> _generarRecibo() async {
    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Recibo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ID ${widget.clienteId}'),
            const SizedBox(height: 8),
            Text(
              'Total a cobrar: ${_currencyFormat.format(_getTotalSeleccionado())}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Formas de pago: ${_formasPago.length}',
            ),
            const SizedBox(height: 16),
            const Text(
              '¿Confirma la generación del recibo?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mostrar indicador de carga
    if (!mounted) return;
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
                Text('Generando recibo...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final totalCobrado = _getTotalSeleccionado();

      final resultado = await ref
          .read(cobranzasClientesNotifierProvider.notifier)
          .generarRecibo(
            clienteId: widget.clienteId,
            transaccionesAPagar: _selectedPagos,
            formasPago: _formasPago,
          );

      final numeroRecibo = resultado['numero_recibo']!;
      final numeroAsiento = resultado['numero_asiento']!;

      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      // Limpiar selección
      setState(() {
        _selectedPagos.clear();
        _formasPago.clear();
      });

      // Refrescar providers
      ref.invalidate(comprobantesPendientesClienteProvider);
      ref.invalidate(saldoClienteProvider);

      await Future.delayed(const Duration(milliseconds: 100));

      // Mostrar diálogo de éxito
      if (!mounted) return;
      final idTransaccion = resultado['id_transaccion'] as int;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 8),
              Text('Recibo Generado'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recibo Nro. $numeroRecibo',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Asiento Nro. $numeroAsiento',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Total: ${_currencyFormat.format(totalCobrado)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'El recibo ha sido generado correctamente.',
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _imprimirRecibo(idTransaccion);
              },
              icon: const Icon(Icons.print),
              label: const Text('Imprimir'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      if (mounted) Navigator.pop(context);

      // Mostrar error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar recibo: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _imprimirRecibo(int idTransaccion) async {
    // Mostrar indicador de carga
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
      final pdfService = ReciboClientePdfService(supabase);

      final pdf = await pdfService.generarReciboPdf(
        idTransaccion: idTransaccion,
      );

      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      // Imprimir
      await pdfService.imprimirRecibo(pdf);
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      if (mounted) Navigator.pop(context);

      // Mostrar error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
