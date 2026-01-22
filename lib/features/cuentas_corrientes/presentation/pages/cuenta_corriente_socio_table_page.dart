import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;
import '../../providers/cuentas_corrientes_provider.dart';
import '../../models/cuenta_corriente_completa_model.dart';
import '../../../socios/providers/socios_provider.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';

/// Página de cuenta corriente con formato de tabla (similar al sistema de escritorio)
class CuentaCorrienteSocioTablePage extends ConsumerStatefulWidget {
  final int socioId;

  const CuentaCorrienteSocioTablePage({
    super.key,
    required this.socioId,
  });

  @override
  ConsumerState<CuentaCorrienteSocioTablePage> createState() =>
      _CuentaCorrienteSocioTablePageState();
}

class _CuentaCorrienteSocioTablePageState
    extends ConsumerState<CuentaCorrienteSocioTablePage> {
  bool _soloPendientes = true;

  @override
  Widget build(BuildContext context) {
    final socioAsync = ref.watch(socioByIdProvider(widget.socioId));
    final saldoAsync = ref.watch(saldoSocioProvider(widget.socioId));

    final searchParams = CuentasCorrientesSearchParams(
      socioId: widget.socioId,
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
        title: socioAsync.when(
          data: (socio) =>
              Text('Cuenta Corriente - ${socio?.apellido}, ${socio?.nombre}'),
          loading: () => const Text('Cuenta Corriente'),
          error: (_, __) => const Text('Cuenta Corriente'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportarExcel(movimientosAsync, socioAsync),
            tooltip: 'Exportar a Excel',
          ),
          // TODO: Descomentar cuando se implemente nueva transacción
          // IconButton(
          //   icon: const Icon(Icons.add),
          //   onPressed: () {
          //     context.go('/cuentas-corrientes/nueva?socioId=${widget.socioId}');
          //   },
          //   tooltip: 'Nueva Transacción',
          // ),
        ],
      ),
      body: Column(
        children: [
          // Información del socio y saldos (compacto)
          _buildInfoHeader(socioAsync, saldoAsync),

          const Divider(height: 1),

          // Filtro
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

          // Tabla de movimientos
          Expanded(
            child: _buildMovimientosTable(movimientosAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHeader(
    AsyncValue socioAsync,
    AsyncValue<Map<String, double>> saldoAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Row(
        children: [
          Expanded(
            child: socioAsync.when(
              data: (socio) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${socio?.id} - ${socio?.apellido}, ${socio?.nombre}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (socio?.numeroDocumento != null)
                    Text(
                      'DNI: ${socio.numeroDocumento}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                ],
              ),
              loading: () => const Text('Cargando...'),
              error: (_, __) => const Text('Error cargando socio'),
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
                    label: Text('Rendición',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Acciones',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _buildRows(movimientos),
            ),
          ),
        );
      },
      loading: () => const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(),
        ),
      ),
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

    // Iterar en orden cronológico (ya vienen ordenados por fecha ASC)
    for (final cuenta in movimientos) {
      // Calcular debe/haber según el signo del tipo de comprobante
      // signo = 1 para débito (debe), signo = -1 para crédito (haber)

      // Si estamos mostrando solo pendientes, usar el saldo pendiente (importe - cancelado)
      // en lugar del importe total
      final importeAMostrar = _soloPendientes
          ? (cuenta.header.importe ?? 0) - (cuenta.header.cancelado ?? 0)
          : cuenta.header.importe ?? 0;

      final signo = cuenta.header.signo ?? 1;  // Default a débito si no hay signo

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
            DataCell(
              Text(cuenta.header.puntoVenta ?? ''),
            ),
            DataCell(
              Text(cuenta.header.documentoNumero ?? ''),
            ),
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
              Text(cuenta.header.rendicion ?? ''),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TODO: Descomentar cuando se implemente registrar pago
                  // if (isPendiente)
                  //   IconButton(
                  //     icon: const Icon(Icons.payment,
                  //         size: 18, color: Colors.blue),
                  //     onPressed: () => _showRegistrarPagoDialog(cuenta),
                  //     tooltip: 'Registrar Pago',
                  //     padding: EdgeInsets.zero,
                  //     constraints: const BoxConstraints(),
                  //   ),
                  IconButton(
                    icon: const Icon(Icons.visibility,
                        size: 18, color: Colors.grey),
                    onPressed: () => _showDetalleDialog(cuenta),
                    tooltip: 'Ver Detalle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.edit, size: 18, color: Colors.orange),
                    onPressed: () {
                      context.go(
                          '/cuentas-corrientes/${cuenta.header.idtransaccion}');
                    },
                    tooltip: 'Editar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (userRole.esAdministrador)
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
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
        title: Text('Detalle - ${cuenta.header.tipoComprobanteDescripcion}'),
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
                          'x${item.cantidad.toStringAsFixed(0) ?? '1'} = \$${item.importeTotal.toStringAsFixed(2)}',
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

  Future<void> _showRegistrarPagoDialog(CuentaCorrienteCompleta cuenta) async {
    final montoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Saldo pendiente: \$${cuenta.header.saldoPendiente.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: montoController,
                decoration: const InputDecoration(
                  labelText: 'Monto a pagar',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese un monto';
                  }
                  final monto = double.tryParse(value);
                  if (monto == null || monto <= 0) {
                    return 'Monto inválido';
                  }
                  if (monto > cuenta.header.saldoPendiente) {
                    return 'El monto supera el saldo pendiente';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final monto = double.parse(montoController.text);

              try {
                await ref
                    .read(cuentasCorrientesNotifierProvider.notifier)
                    .registrarPago(
                      cuenta.header.idtransaccion!,
                      monto,
                      widget.socioId,
                    );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Pago registrado correctamente')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
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
              widget.socioId,
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
    AsyncValue socioAsync,
  ) async {
    // Verificar que tenemos datos
    if (!movimientosAsync.hasValue || movimientosAsync.value!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    try {
      final movimientos = movimientosAsync.value!;
      final socio = socioAsync.hasValue ? socioAsync.value : null;
      final nombreSocio = socio != null
          ? '${socio.apellido}, ${socio.nombre}'
          : 'Socio ${widget.socioId}';

      // Crear el archivo Excel
      final excel = Excel.createExcel();
      final sheet = excel['Cuenta Corriente'];

      // Eliminar la hoja por defecto
      excel.delete('Sheet1');

      // Estilos para encabezados
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      final currencyStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Right,
      );

      // Título
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
        'Cuenta Corriente - $nombreSocio',
      );
      sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
      );
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('G1'));

      // Subtítulo con filtro
      final filtroTexto = _soloPendientes ? 'Solo Pendientes' : 'Todos los Movimientos';
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Filtro: $filtroTexto - Exportado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      );
      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('G2'));

      // Fila de encabezados (fila 4)
      final headers = ['Fecha', 'Concepto', 'Serie', 'Documento', 'Debe', 'Haber', 'Saldo'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Calcular saldo acumulado y agregar datos
      double saldoAcumulado = 0;
      int rowIndex = 4;

      for (final cuenta in movimientos) {
        final debe = cuenta.header.importe ?? 0;
        final haber = cuenta.header.cancelado ?? 0;
        saldoAcumulado += debe - haber;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
            TextCellValue(DateFormat('dd/MM/yyyy').format(cuenta.header.fecha));

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
            TextCellValue(cuenta.header.tipoComprobanteDescripcion ?? cuenta.header.tipoComprobante);

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
            TextCellValue(cuenta.header.puntoVenta ?? '');

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
            TextCellValue(cuenta.header.documentoNumero ?? '');

        // Debe
        final cellDebe = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
        cellDebe.value = DoubleCellValue(debe);
        cellDebe.cellStyle = currencyStyle;

        // Haber
        final cellHaber = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
        cellHaber.value = DoubleCellValue(haber);
        cellHaber.cellStyle = currencyStyle;

        // Saldo
        final cellSaldo = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
        cellSaldo.value = DoubleCellValue(saldoAcumulado);
        cellSaldo.cellStyle = currencyStyle;

        rowIndex++;
      }

      // Fila de totales
      rowIndex++;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
          TextCellValue('TOTALES:');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle =
          CellStyle(bold: true);

      final totalDebe = movimientos.fold<double>(0, (sum, c) => sum + (c.header.importe ?? 0));
      final totalHaber = movimientos.fold<double>(0, (sum, c) => sum + (c.header.cancelado ?? 0));

      final cellTotalDebe = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
      cellTotalDebe.value = DoubleCellValue(totalDebe);
      cellTotalDebe.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Right);

      final cellTotalHaber = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
      cellTotalHaber.value = DoubleCellValue(totalHaber);
      cellTotalHaber.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Right);

      final cellTotalSaldo = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
      cellTotalSaldo.value = DoubleCellValue(saldoAcumulado);
      cellTotalSaldo.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Right);

      // Ajustar anchos de columna
      sheet.setColumnWidth(0, 12);  // Fecha
      sheet.setColumnWidth(1, 25);  // Concepto
      sheet.setColumnWidth(2, 10);  // Serie
      sheet.setColumnWidth(3, 12);  // Documento
      sheet.setColumnWidth(4, 12);  // Debe
      sheet.setColumnWidth(5, 12);  // Haber
      sheet.setColumnWidth(6, 12);  // Saldo

      // Generar el archivo y descargar
      final bytes = excel.save();
      if (bytes != null) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'CuentaCorriente_${widget.socioId}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx')
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
