import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;
import '../../providers/cuentas_corrientes_provider.dart';
import '../../providers/cobranzas_provider.dart';
import '../../models/cuenta_corriente_completa_model.dart';
import '../../../profesionales/providers/profesionales_provider.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';

/// Página de cuenta corriente de profesional con formato de tabla
class CuentaCorrienteProfesionalTablePage extends ConsumerStatefulWidget {
  final int profesionalId;

  const CuentaCorrienteProfesionalTablePage({
    super.key,
    required this.profesionalId,
  });

  @override
  ConsumerState<CuentaCorrienteProfesionalTablePage> createState() =>
      _CuentaCorrienteProfesionalTablePageState();
}

class _CuentaCorrienteProfesionalTablePageState
    extends ConsumerState<CuentaCorrienteProfesionalTablePage> {
  bool _soloPendientes = true;

  @override
  Widget build(BuildContext context) {
    final profesionalAsync =
        ref.watch(profesionalByIdProvider(widget.profesionalId));
    final saldoAsync =
        ref.watch(saldoProfesionalProvider(widget.profesionalId));

    final searchParams = CuentasCorrientesSearchParams(
      profesionalId: widget.profesionalId,
      soloPendientes: _soloPendientes,
    );
    final movimientosAsync = ref.watch(
      cuentasCorrientesSearchProvider(searchParams),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Ir a Inicio',
          onPressed: () => context.go('/'),
        ),
        title: profesionalAsync.when(
          data: (p) => Text(
              'Cuenta Corriente - ${p?.apellido ?? ''}, ${p?.nombre ?? ''}'),
          loading: () => const Text('Cuenta Corriente'),
          error: (_, __) => const Text('Cuenta Corriente'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments),
            onPressed: () => context
                .go('/cobranzas-profesionales/${widget.profesionalId}'),
            tooltip: 'Ir a Cobranzas',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportarExcel(movimientosAsync, profesionalAsync),
            tooltip: 'Exportar a Excel',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoHeader(profesionalAsync, saldoAsync),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _soloPendientes,
                  onChanged: (value) {
                    setState(() => _soloPendientes = value ?? false);
                  },
                ),
                const Text('Solo pendientes'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildMovimientosTable(movimientosAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHeader(
    AsyncValue profesionalAsync,
    AsyncValue<Map<String, double>> saldoAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.teal[50],
      child: Row(
        children: [
          Expanded(
            child: profesionalAsync.when(
              data: (p) => p == null
                  ? const Text('Profesional no encontrado')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.id} - ${p.apellido}, ${p.nombre}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (p.numeroDocumento != null)
                          Text(
                            'DNI: ${p.numeroDocumento}',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                      ],
                    ),
              loading: () => const Text('Cargando...'),
              error: (_, __) => const Text('Error cargando profesional'),
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
                    'Saldo Total: \$${saldoTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDeudor ? Colors.red : Colors.green,
                    ),
                  ),
                  Text(
                    '${saldo['total_transacciones']?.toInt() ?? 0} movimientos',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              );
            },
            loading: () => const Text('...'),
            error: (_, __) => const Text('Error'),
          ),
        ],
      ),
    );
  }

  Widget _buildMovimientosTable(
    AsyncValue<List<CuentaCorrienteCompleta>> movimientosAsync,
  ) {
    return movimientosAsync.when(
      data: (movimientos) {
        if (movimientos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _soloPendientes
                      ? 'No hay movimientos pendientes'
                      : 'No hay movimientos registrados',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 16,
              headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
              columns: const [
                DataColumn(
                    label: Text('Fecha',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Concepto',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Serie',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Documento',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Debe',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Haber',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Saldo',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Acciones',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _buildRows(movimientos),
            ),
          ),
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

  List<DataRow> _buildRows(List<CuentaCorrienteCompleta> movimientos) {
    double saldoAcumulado = 0;
    final rows = <DataRow>[];
    final userRole = ref.read(userRoleProvider);

    for (final cuenta in movimientos) {
      final importeAMostrar = _soloPendientes
          ? (cuenta.header.importe ?? 0) - (cuenta.header.cancelado ?? 0)
          : cuenta.header.importe ?? 0;

      final signo = cuenta.header.signo ?? 1;
      final debe = signo == 1 ? importeAMostrar : 0.0;
      final haber = signo == -1 ? importeAMostrar : 0.0;
      saldoAcumulado += debe - haber;

      final isPendiente = !cuenta.header.estaCancelado;
      final rowColor = isPendiente ? Colors.orange[50] : null;

      rows.add(
        DataRow(
          color: WidgetStateProperty.all(rowColor),
          cells: [
            DataCell(
              Text(DateFormat('dd/MM/yyyy').format(cuenta.header.fecha)),
            ),
            DataCell(
              Text(
                '${cuenta.header.tipoComprobante} - ${cuenta.header.tipoComprobanteDescripcion ?? ''}',
              ),
            ),
            DataCell(Text(cuenta.header.puntoVenta ?? '')),
            DataCell(Text(cuenta.header.documentoNumero ?? '')),
            DataCell(
              Text(
                debe > 0 ? debe.toStringAsFixed(2) : '0.00',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            DataCell(
              Text(
                haber > 0 ? haber.toStringAsFixed(2) : '0.00',
                style: const TextStyle(color: Colors.green),
              ),
            ),
            DataCell(
              Text(
                saldoAcumulado.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: saldoAcumulado > 0 ? Colors.red : Colors.green,
                ),
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility,
                        size: 18, color: Colors.grey),
                    onPressed: () => _showDetalleDialog(cuenta),
                    tooltip: 'Ver Detalle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (userRole.esAdministrador &&
                      cuenta.header.tipoComprobante == 'COB')
                    IconButton(
                      icon: const Icon(Icons.print,
                          size: 18, color: Colors.teal),
                      onPressed: () => _reimprimirRecibo(cuenta),
                      tooltip: 'Reimprimir Recibo',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (userRole.esAdministrador)
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => _confirmDelete(cuenta),
                      tooltip: 'Eliminar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return rows;
  }

  Future<void> _showDetalleDialog(CuentaCorrienteCompleta cuenta) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Detalle - ${cuenta.header.tipoComprobanteDescripcion ?? cuenta.header.tipoComprobante}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Documento: ${cuenta.header.documentoNumero ?? 'S/N'}'),
              Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy').format(cuenta.header.fecha)}'),
              if (cuenta.header.vencimiento != null)
                Text(
                    'Vencimiento: ${DateFormat('dd/MM/yyyy').format(cuenta.header.vencimiento!)}'),
              const Divider(),
              const Text('Items:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...cuenta.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                              '${item.concepto} - ${item.conceptoDescripcion ?? ''}'),
                        ),
                        Text(
                          'x${item.cantidad.toStringAsFixed(0)} = \$${item.importeTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '\$${cuenta.totalItems.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              if (cuenta.header.cancelado != null &&
                  cuenta.header.cancelado! > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cancelado:',
                        style: TextStyle(color: Colors.green)),
                    Text(
                      '\$${cuenta.header.cancelado!.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _reimprimirRecibo(CuentaCorrienteCompleta cuenta) async {
    final claveController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reimprimir Recibo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recibo Nro. ${cuenta.header.documentoNumero ?? 'S/N'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Ingrese la clave de administrador:'),
            const SizedBox(height: 8),
            TextField(
              controller: claveController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Clave',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              onSubmitted: (_) => Navigator.pop(context, true),
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

    final claveIngresada = claveController.text;
    claveController.dispose();
    if (confirmed != true) return;

    const adminClave = 'SAO2026';
    if (claveIngresada != adminClave) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clave incorrecta'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final nroRecibo = int.tryParse(cuenta.header.documentoNumero ?? '');
    if (nroRecibo == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede obtener el número de recibo'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

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
                Text('Generando PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final pdfService = ref.read(reciboPdfServiceProvider);
      final pdf = await pdfService.generarReciboPdf(numeroRecibo: nroRecibo);

      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.print, color: Colors.teal),
              const SizedBox(width: 8),
              Text('Recibo Nro. $nroRecibo'),
            ],
          ),
          content: const Text('¿Qué desea hacer con el recibo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await pdfService.imprimirRecibo(pdf);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              icon: const Icon(Icons.print),
              label: const Text('Imprimir'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await pdfService.compartirRecibo(
                    pdf: pdf,
                    numeroRecibo: nroRecibo,
                    nombreSocio: 'recibo_$nroRecibo',
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartir'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(CuentaCorrienteCompleta cuenta) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Está seguro que desea eliminar la transacción '
          '${cuenta.header.tipoComprobante} - ${cuenta.header.documentoNumero ?? 'S/N'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(cuentasCorrientesNotifierProvider.notifier)
            .deleteCuentaCorriente(
              cuenta.header.idtransaccion!,
              0, // No hay socioId para profesionales
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Transacción eliminada correctamente')),
          );
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
      }
    }
  }

  Future<void> _exportarExcel(
    AsyncValue<List<CuentaCorrienteCompleta>> movimientosAsync,
    AsyncValue profesionalAsync,
  ) async {
    if (!movimientosAsync.hasValue || movimientosAsync.value!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    try {
      final movimientos = movimientosAsync.value!;
      final p = profesionalAsync.hasValue ? profesionalAsync.value : null;
      final nombreProfesional = p != null
          ? '${p.apellido}, ${p.nombre}'
          : 'Profesional ${widget.profesionalId}';

      final excel = Excel.createExcel();
      final sheet = excel['Cuenta Corriente'];
      excel.delete('Sheet1');

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#00897B'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );
      final currencyStyle =
          CellStyle(horizontalAlign: HorizontalAlign.Right);

      sheet.cell(CellIndex.indexByString('A1')).value =
          TextCellValue('Cuenta Corriente - $nombreProfesional');
      sheet.cell(CellIndex.indexByString('A1')).cellStyle =
          CellStyle(bold: true, fontSize: 14);
      sheet.merge(
          CellIndex.indexByString('A1'), CellIndex.indexByString('G1'));

      final filtroTexto =
          _soloPendientes ? 'Solo Pendientes' : 'Todos los Movimientos';
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
          'Filtro: $filtroTexto - Exportado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
      sheet.merge(
          CellIndex.indexByString('A2'), CellIndex.indexByString('G2'));

      final headers = [
        'Fecha',
        'Concepto',
        'Serie',
        'Documento',
        'Debe',
        'Haber',
        'Saldo'
      ];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      double saldoAcumulado = 0;
      int rowIndex = 4;

      for (final cuenta in movimientos) {
        final signo = cuenta.header.signo ?? 1;
        final importe = cuenta.header.importe ?? 0;
        final debe = signo == 1 ? importe : 0.0;
        final haber = signo == -1 ? importe : 0.0;
        saldoAcumulado += debe - haber;

        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: rowIndex))
            .value = TextCellValue(
                DateFormat('dd/MM/yyyy').format(cuenta.header.fecha));
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(cuenta.header.tipoComprobanteDescripcion ??
            cuenta.header.tipoComprobante);
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 2, rowIndex: rowIndex))
            .value = TextCellValue(cuenta.header.puntoVenta ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 3, rowIndex: rowIndex))
            .value = TextCellValue(cuenta.header.documentoNumero ?? '');

        final cellDebe = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
        cellDebe.value = DoubleCellValue(debe);
        cellDebe.cellStyle = currencyStyle;

        final cellHaber = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
        cellHaber.value = DoubleCellValue(haber);
        cellHaber.cellStyle = currencyStyle;

        final cellSaldo = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
        cellSaldo.value = DoubleCellValue(saldoAcumulado);
        cellSaldo.cellStyle = currencyStyle;

        rowIndex++;
      }

      sheet.setColumnWidth(0, 12);
      sheet.setColumnWidth(1, 25);
      sheet.setColumnWidth(2, 10);
      sheet.setColumnWidth(3, 12);
      sheet.setColumnWidth(4, 12);
      sheet.setColumnWidth(5, 12);
      sheet.setColumnWidth(6, 12);

      final bytes = excel.save();
      if (bytes != null) {
        final blob = html.Blob([bytes],
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
              'download',
              'CuentaCorriente_Prof${widget.profesionalId}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel exportado correctamente')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
