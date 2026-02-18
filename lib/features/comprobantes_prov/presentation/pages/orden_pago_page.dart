import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/comprobante_prov_model.dart';
import '../../providers/orden_pago_provider.dart';
import '../../providers/comprobantes_prov_provider.dart';
import '../../services/orden_pago_pdf_service.dart';
import '../../../proveedores/providers/proveedores_provider.dart';
import '../../../cuentas_corrientes/providers/conceptos_tesoreria_provider.dart';
import '../../../cuentas_corrientes/models/concepto_tesoreria_model.dart';
import '../../../asientos/presentation/widgets/cuentas_search_dialog.dart';
import '../../../cuentas/models/cuenta_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/date_picker_utils.dart';

/// Página principal de orden de pago a proveedores
class OrdenPagoPage extends ConsumerStatefulWidget {
  final int proveedorId;

  const OrdenPagoPage({
    super.key,
    required this.proveedorId,
  });

  @override
  ConsumerState<OrdenPagoPage> createState() => _OrdenPagoPageState();
}

class _OrdenPagoPageState extends ConsumerState<OrdenPagoPage> {
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

  Future<void> _mostrarDialogoNuevaFactura() async {
    final result = await showDialog<CompProvHeader>(
      context: context,
      builder: (context) => _NuevaFacturaRapidaDialog(
        proveedorId: widget.proveedorId,
      ),
    );

    if (result != null && mounted) {
      // La factura fue creada, seleccionarla automáticamente para pagar
      setState(() {
        _selectedPagos[result.idTransaccion!] = result.totalImporte;
      });

      // Refrescar la lista de comprobantes pendientes
      ref.invalidate(
          comprobantesPendientesProveedorProvider(widget.proveedorId));
      ref.invalidate(saldoProveedorProvider(widget.proveedorId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Factura ${result.nroComprobante} creada y seleccionada para pago'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final proveedorAsync = ref.watch(proveedorProvider(widget.proveedorId));
    final saldoAsync = ref.watch(saldoProveedorProvider(widget.proveedorId));
    final pendientesAsync =
        ref.watch(comprobantesPendientesProveedorProvider(widget.proveedorId));

    return Scaffold(
      appBar: AppBar(
        title: proveedorAsync.when(
          data: (proveedor) =>
              Text('Orden de Pago - ${proveedor?.razonSocial ?? "Proveedor"}'),
          loading: () => const Text('Orden de Pago'),
          error: (_, __) => const Text('Orden de Pago'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/orden-pago'),
        ),
        actions: [
          TextButton.icon(
            onPressed: _mostrarDialogoNuevaFactura,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Nueva Factura',
              style: TextStyle(color: Colors.white),
            ),
          ),
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
                  backgroundColor: Colors.orange,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Información del proveedor y saldos
          _buildInfoHeader(proveedorAsync, saldoAsync),
          const Divider(height: 1),

          // Tabla de comprobantes pendientes
          Expanded(
            flex: 2,
            child: _buildComprobantesPendientes(pendientesAsync),
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
    AsyncValue proveedorAsync,
    AsyncValue<Map<String, double>> saldoAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange[50],
      child: Row(
        children: [
          const Icon(Icons.payment, color: Colors.orange, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: proveedorAsync.when(
              data: (proveedor) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${proveedor?.codigo} - ${proveedor?.razonSocial}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (proveedor?.cuit?.isNotEmpty == true)
                    Text(
                      'CUIT: ${proveedor!.cuit}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error cargando proveedor'),
            ),
          ),
          saldoAsync.when(
            data: (saldo) {
              final saldoTotal = saldo['saldo_total'] ?? 0.0;
              final debemos = saldoTotal > 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Saldo a Pagar: ${_currencyFormat.format(saldoTotal)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: debemos ? Colors.red : Colors.green,
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

  Widget _buildComprobantesPendientes(
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
                  'No hay comprobantes pendientes de pago',
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
                      'Seleccione los comprobantes a pagar e ingrese el monto para cada uno',
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
            // Tabla de comprobantes
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
                          label: Text('A Pagar',
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

      final tipoData = comp['tip_comp_mod_header'] as Map<String, dynamic>?;
      final tipoDesc = tipoData != null
          ? '${tipoData['comprobante']} - ${tipoData['descripcion']}'
          : 'Tipo ${comp['tipo_comprobante']}';

      rows.add(
        DataRow(
          selected: isSelected,
          color: WidgetStateProperty.all(
              isSelected ? Colors.orange[50] : Colors.red[50]),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        comp['tipo_factura'],
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
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
                            _pagosControllers[idTransaccion] =
                                TextEditingController(
                              text: _selectedPagos[idTransaccion]
                                  ?.toStringAsFixed(2),
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
    // Usamos conceptos de egreso para orden de pago
    final conceptosAsync = ref.watch(conceptosCarteraEgresoProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Medios de Pago',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Total a Pagar: ${_currencyFormat.format(_getTotalSeleccionado())}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Total Medios de Pago: ${_currencyFormat.format(_getTotalFormasPago())}',
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
                      'Seleccione comprobantes pendientes para agregar medios de pago',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return Row(
                  children: [
                    // Lista de medios de pago disponibles
                    Expanded(
                      flex: 2,
                      child: Card(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.orange[50],
                              child: const Row(
                                children: [
                                  Icon(Icons.account_balance_wallet,
                                      color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text(
                                    'Medios de Pago Disponibles',
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
                                          color: Colors.orange),
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
                    // Medios de pago seleccionados
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
                                    'Medios de Pago Seleccionados',
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
                                        'Agregue medios de pago',
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

                                        if (!_formasPagoControllers
                                            .containsKey(conceptoId)) {
                                          _formasPagoControllers[conceptoId] =
                                              TextEditingController(
                                            text: monto.toStringAsFixed(2),
                                          );
                                        }

                                        return ListTile(
                                          title:
                                              Text(concepto?.descripcion ?? ''),
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
                                              controller:
                                                  _formasPagoControllers[
                                                      conceptoId],
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
                            // Botón de generar orden de pago
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: FilledButton.icon(
                                onPressed:
                                    _canGenerateOP() ? _generarOrdenPago : null,
                                icon: const Icon(Icons.payment),
                                label: const Text('Generar Orden de Pago'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  backgroundColor: Colors.orange,
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

  bool _canGenerateOP() {
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

  Future<void> _generarOrdenPago() async {
    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Orden de Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Proveedor: ID ${widget.proveedorId}'),
            const SizedBox(height: 8),
            Text(
              'Total a pagar: ${_currencyFormat.format(_getTotalSeleccionado())}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Medios de pago: ${_formasPago.length}',
            ),
            const SizedBox(height: 16),
            const Text(
              '¿Confirma la generación de la orden de pago?',
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
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
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
                Text('Generando orden de pago...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final totalPagado = _getTotalSeleccionado();

      final resultado =
          await ref.read(ordenPagoNotifierProvider.notifier).generarOrdenPago(
                proveedorId: widget.proveedorId,
                transaccionesAPagar: _selectedPagos,
                formasPago: _formasPago,
              );

      final numeroOP = resultado['numero_orden_pago']!;
      final numeroAsiento = resultado['numero_asiento'] as int?; // null si falló el asiento
      final asientoError = resultado['asiento_error'] as String?;

      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      // Limpiar selección
      setState(() {
        _selectedPagos.clear();
        _formasPago.clear();
      });

      // Refrescar providers
      ref.invalidate(comprobantesPendientesProveedorProvider);
      ref.invalidate(saldoProveedorProvider);

      await Future.delayed(const Duration(milliseconds: 100));

      // Mostrar diálogo de éxito con opción de imprimir
      final idTransaccionOP = resultado['id_transaccion'] as int;
      if (!mounted) return;

      // Si el asiento falló, mostrar advertencia antes del diálogo
      if (asientoError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Advertencia: OP generada pero falló el asiento contable: $asientoError'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
          ),
        );
      }

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 8),
              Text('Orden de Pago Generada'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OP Nro. $numeroOP',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              if (numeroAsiento != null)
                Text(
                  'Asiento Nro. $numeroAsiento',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700], size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'Sin asiento contable',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                'Total: ${_currencyFormat.format(totalPagado)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'La orden de pago ha sido generada correctamente.',
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
              label: const Text('Imprimir'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      try {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}

      // Mostrar error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar orden de pago: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _imprimirOrdenPago(int idTransaccion) async {
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
      final pdfService = OrdenPagoPdfService(supabase);
      final pdf =
          await pdfService.generarOrdenPagoPdf(idTransaccion: idTransaccion);

      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      // Imprimir
      await pdfService.imprimirOrdenPago(pdf);
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
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
}

/// Diálogo para crear una factura rápida desde la pantalla de OP
class _NuevaFacturaRapidaDialog extends ConsumerStatefulWidget {
  final int proveedorId;

  const _NuevaFacturaRapidaDialog({required this.proveedorId});

  @override
  ConsumerState<_NuevaFacturaRapidaDialog> createState() =>
      _NuevaFacturaRapidaDialogState();
}

class _NuevaFacturaRapidaDialogState
    extends ConsumerState<_NuevaFacturaRapidaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nroComprobanteController = TextEditingController();
  final _importeController = TextEditingController();
  final _cuentaController = TextEditingController();

  DateTime _fecha = DateTime.now();
  DateTime? _fecha1Venc;
  int? _tipoComprobante;
  String? _tipoFactura;
  bool _isLoading = false;

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _nroComprobanteController.dispose();
    _importeController.dispose();
    _cuentaController.dispose();
    super.dispose();
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

  Future<void> _guardarFactura() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tipoComprobante == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un tipo de comprobante')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final importe = double.parse(_importeController.text.trim());
      final cuenta = int.parse(_cuentaController.text.trim());
      final anioMes = _fecha.year * 100 + _fecha.month;

      final header = CompProvHeader(
        comprobante: 0,
        anioMes: anioMes,
        fecha: _fecha,
        proveedor: widget.proveedorId,
        tipoComprobante: _tipoComprobante!,
        nroComprobante: _nroComprobanteController.text.trim(),
        tipoFactura: _tipoFactura,
        totalImporte: importe,
        cancelado: 0,
        fecha1Venc: _fecha1Venc,
        estado: 'P',
        fechaReal: _fecha,
      );

      // Crear un item simple con todo el importe
      final item = CompProvItem(
        comprobante: 0,
        anioMes: anioMes,
        item: 1,
        concepto: 'GTO', // Gasto
        cuenta: cuenta,
        importe: importe,
        baseContable: importe,
        alicuota: 0,
      );

      final notifier = ref.read(comprobantesProvNotifierProvider.notifier);
      final comprobanteCreado = await notifier.crearComprobante(header, [item]);

      if (mounted) {
        Navigator.pop(context, comprobanteCreado);
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
    final tiposAsync = ref.watch(tiposComprobanteCompraProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.receipt_long, color: Colors.orange),
          SizedBox(width: 8),
          Text('Nueva Factura Rápida'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tipo de comprobante
                tiposAsync.when(
                  data: (tipos) {
                    // Filtrar solo facturas (multiplicador = 1)
                    final tiposFactura =
                        tipos.where((t) => t.multiplicador == 1).toList();
                    return DropdownButtonFormField<int?>(
                      initialValue: _tipoComprobante,
                      decoration: const InputDecoration(
                        labelText: 'Tipo Comprobante *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: tiposFactura
                          .map((tipo) => DropdownMenuItem<int?>(
                                value: tipo.codigo,
                                child: Text(tipo.descripcion),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _tipoComprobante = value);
                      },
                      validator: (value) =>
                          value == null ? 'Seleccione tipo' : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error cargando tipos'),
                ),
                const SizedBox(height: 16),

                // Número de comprobante y tipo factura
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _nroComprobanteController,
                        decoration: const InputDecoration(
                          labelText: 'Nro. Comprobante *',
                          border: OutlineInputBorder(),
                          hintText: 'XXXX-XXXXXXXX',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) =>
                            value?.trim().isEmpty == true ? 'Requerido' : null,
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
                          DropdownMenuItem(value: null, child: Text('--')),
                          DropdownMenuItem(value: 'A', child: Text('A')),
                          DropdownMenuItem(value: 'B', child: Text('B')),
                          DropdownMenuItem(value: 'C', child: Text('C')),
                        ],
                        onChanged: (value) {
                          setState(() => _tipoFactura = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fechas
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
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() => _fecha1Venc = null);
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

                // Importe y cuenta
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value?.trim().isEmpty == true) return 'Requerido';
                          if (double.tryParse(value!.trim()) == null) {
                            return 'Número inválido';
                          }
                          return null;
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
                          if (value?.trim().isEmpty == true) return 'Requerido';
                          if (int.tryParse(value!.trim()) == null) {
                            return 'Número inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
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
        FilledButton.icon(
          onPressed: _isLoading ? null : _guardarFactura,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save),
          label: const Text('Crear y Seleccionar'),
        ),
      ],
    );
  }
}
