import 'package:flutter/material.dart' hide Border;
import 'package:flutter/material.dart' as material show Border, BorderSide;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import '../../models/cuenta_corriente_resumen.dart';
import '../../providers/cuentas_corrientes_provider.dart';

class ResumenCuentasCorrientesPage extends ConsumerWidget {
  const ResumenCuentasCorrientesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenAsync = ref.watch(resumenCuentasCorrientesProvider);
    final paginaActual = ref.watch(resumenCuentasCorrientesPaginaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen Cuentas Corrientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar Todo a Excel',
            onPressed: () => _exportarATodoExcel(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () {
              ref.invalidate(resumenCuentasCorrientesProvider);
            },
          ),
        ],
      ),
      body: resumenAsync.when(
        data: (data) {
          final socios = data['items'] as List<CuentaCorrienteResumen>;
          final totalCount = data['totalCount'] as int;
          return _buildDataTableWithPagination(context, ref, socios, totalCount, paginaActual);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(resumenCuentasCorrientesProvider);
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTableWithPagination(
    BuildContext context,
    WidgetRef ref,
    List<CuentaCorrienteResumen> socios,
    int totalCount,
    int paginaActual,
  ) {
    if (socios.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay socios activos',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Column(
      children: [
        // Estadísticas y paginación info
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat(
                    'Total Socios',
                    totalCount.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildStat(
                    'Con Saldo',
                    socios.where((s) => s.tieneSaldoPendiente).length.toString(),
                    Icons.warning,
                    Colors.orange,
                  ),
                  _buildStat(
                    'Saldo Total',
                    currencyFormat.format(
                      socios.fold<double>(0, (sum, s) => sum + s.saldo),
                    ),
                    Icons.attach_money,
                    Colors.green,
                  ),
                  _buildStat(
                    'RDA Pendiente',
                    currencyFormat.format(
                      socios.fold<double>(0, (sum, s) => sum + s.rdaPendiente),
                    ),
                    Icons.receipt,
                    Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Mostrando ${paginaActual * 50 + 1}-${(paginaActual * 50 + socios.length).clamp(0, totalCount)} de $totalCount socios',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Tabla
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.primaryContainer,
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Socio',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Apellido',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Nombre',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Grupo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Saldo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'RDA Pendiente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Teléfono',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Acción',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: socios.map((socio) {
                    return DataRow(
                      onSelectChanged: (_) => _mostrarDetalleCuenta(context, ref, socio),
                      cells: [
                        DataCell(Text(socio.socioId.toString())),
                        DataCell(Text(socio.apellido)),
                        DataCell(Text(socio.nombre)),
                        DataCell(Text(socio.grupo ?? '-')),
                        DataCell(
                          Text(
                            currencyFormat.format(socio.saldo),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: socio.tieneSaldoPendiente
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            currencyFormat.format(socio.rdaPendiente),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: socio.rdaPendiente > 0
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        DataCell(Text(socio.telefono ?? '-')),
                        DataCell(
                          socio.tieneEmail
                              ? Text(socio.email!)
                              : Text(
                                  'Sin email',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.email),
                            tooltip: 'Enviar resumen por email',
                            color: socio.tieneEmail ? Colors.blue : Colors.grey,
                            onPressed: socio.tieneEmail
                                ? () => _enviarEmail(context, ref, socio)
                                : null,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),

        // Controles de paginación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: material.Border(
              top: material.BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón primera página
              IconButton(
                icon: const Icon(Icons.first_page),
                tooltip: 'Primera página',
                onPressed: paginaActual > 0
                    ? () => ref.read(resumenCuentasCorrientesPaginaProvider.notifier).setPagina(0)
                    : null,
              ),
              const SizedBox(width: 8),

              // Botón anterior
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Página anterior',
                onPressed: paginaActual > 0
                    ? () => ref.read(resumenCuentasCorrientesPaginaProvider.notifier).setPagina(paginaActual - 1)
                    : null,
              ),
              const SizedBox(width: 16),

              // Indicador de página
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Página ${paginaActual + 1} de ${((totalCount - 1) ~/ 50) + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Botón siguiente
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Página siguiente',
                onPressed: (paginaActual + 1) * 50 < totalCount
                    ? () => ref.read(resumenCuentasCorrientesPaginaProvider.notifier).setPagina(paginaActual + 1)
                    : null,
              ),
              const SizedBox(width: 8),

              // Botón última página
              IconButton(
                icon: const Icon(Icons.last_page),
                tooltip: 'Última página',
                onPressed: (paginaActual + 1) * 50 < totalCount
                    ? () => ref.read(resumenCuentasCorrientesPaginaProvider.notifier).setPagina((totalCount - 1) ~/ 50)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Future<void> _mostrarDetalleCuenta(
    BuildContext context,
    WidgetRef ref,
    CuentaCorrienteResumen socio,
  ) async {
    // Obtener el detalle completo de la cuenta corriente del socio
    final cuentasAsync = await ref.read(
      cuentasCorrientesSearchProvider(
        CuentasCorrientesSearchParams(socioId: socio.socioId),
      ).future,
    );

    if (!context.mounted) return;

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
          child: Column(
            children: [
              // Encabezado
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalle Cuenta Corriente',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Socio #${socio.socioId} - ${socio.apellido}, ${socio.nombre}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Estadísticas
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatSmall(
                      'Saldo Total',
                      currencyFormat.format(socio.saldo),
                      socio.tieneSaldoPendiente ? Colors.red : Colors.green,
                    ),
                    _buildStatSmall(
                      'RDA Pendiente',
                      currencyFormat.format(socio.rdaPendiente),
                      Colors.orange,
                    ),
                    _buildStatSmall(
                      'Movimientos',
                      cuentasAsync.length.toString(),
                      Colors.blue,
                    ),
                  ],
                ),
              ),

              // Tabla de movimientos
              Expanded(
                child: cuentasAsync.isEmpty
                    ? const Center(
                        child: Text('No hay movimientos registrados'),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              Theme.of(context).colorScheme.secondaryContainer,
                            ),
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Fecha',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Tipo',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Comprobante',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Doc. Nro',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Importe',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text(
                                  'Cancelado',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text(
                                  'Saldo',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text(
                                  'Estado',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            rows: cuentasAsync.map((cuenta) {
                              final saldo = cuenta.header.saldoPendiente;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(dateFormat.format(cuenta.header.fecha)),
                                  ),
                                  DataCell(
                                    Text(cuenta.header.tipoComprobanteDescripcion ?? '-'),
                                  ),
                                  DataCell(
                                    Text(cuenta.header.tipoComprobante),
                                  ),
                                  DataCell(
                                    Text(cuenta.header.documentoNumero ?? '-'),
                                  ),
                                  DataCell(
                                    Text(
                                      currencyFormat.format(cuenta.header.importe ?? 0),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      currencyFormat.format(cuenta.header.cancelado ?? 0),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      currencyFormat.format(saldo),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: saldo > 0 ? Colors.red : Colors.green,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Chip(
                                      label: Text(
                                        cuenta.header.estaCancelado ? 'Cancelado' : 'Pendiente',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: cuenta.header.estaCancelado
                                          ? Colors.green.shade100
                                          : Colors.orange.shade100,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),

              // Botones de acción
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatSmall(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Future<void> _enviarEmail(
    BuildContext context,
    WidgetRef ref,
    CuentaCorrienteResumen socio,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar Resumen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Enviar resumen de cuenta corriente a ${socio.apellido}, ${socio.nombre}?'),
            const SizedBox(height: 16),
            Text('Email: ${socio.email}'),
            Text('Saldo: \$${socio.saldo.toStringAsFixed(2)}'),
            Text('RDA Pendiente: \$${socio.rdaPendiente.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      final service = ref.read(cuentasCorrientesResumenServiceProvider);
      await service.enviarEmailResumen(
        socioId: socio.socioId,
        email: socio.email!,
        saldo: socio.saldo,
        rdaPendiente: socio.rdaPendiente,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email enviado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportarATodoExcel(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Text('Exportando todos los registros...'),
            ],
          ),
        ),
      ),
    );

    try {
      // Obtener TODOS los registros sin paginación
      final service = ref.read(cuentasCorrientesResumenServiceProvider);
      final socios = await service.obtenerResumenCompletoParaExportar();

      print('DEBUG: Socios obtenidos para exportar: ${socios.length}');

      if (context.mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
      }

      if (socios.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay datos para exportar'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Exportar usando el método existente
      await _exportarAExcel(context, socios);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportarAExcel(
    BuildContext context,
    List<CuentaCorrienteResumen> socios,
  ) async {
    try {
      // Crear archivo Excel
      final excel = Excel.createExcel();
      
      // Renombrar la hoja por defecto en lugar de eliminarla
      excel.rename('Sheet1', 'Resumen Cuentas Corrientes');
      
      final sheet = excel['Resumen Cuentas Corrientes'];

      // Estilos
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
      );

      // Encabezados
      final headers = [
        'Socio',
        'Apellido',
        'Nombre',
        'Grupo',
        'Saldo',
        'RDA Pendiente',
        'Teléfono',
        'Email',
      ];

      for (var i = 0; i < headers.length; i++) {
        final cell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Datos
      for (var i = 0; i < socios.length; i++) {
        final socio = socios[i];
        final rowIndex = i + 1;

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = IntCellValue(socio.socioId);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(socio.apellido);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = TextCellValue(socio.nombre);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = TextCellValue(socio.grupo ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = DoubleCellValue(socio.saldo);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = DoubleCellValue(socio.rdaPendiente);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
            .value = TextCellValue(socio.telefono ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
            .value = TextCellValue(socio.email ?? '-');
      }

      // Guardar archivo
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Error al generar el archivo Excel');
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'resumen_cuentas_corrientes_$timestamp.xlsx';

      if (kIsWeb) {
        // Para Web: usar descarga del navegador
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Archivo exportado: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Para Mobile/Desktop: guardar en sistema de archivos
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('No se pudo acceder al directorio de descargas');
        }

        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Archivo exportado: $filePath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Abrir carpeta',
                textColor: Colors.white,
                onPressed: () {
                  // TODO: Abrir explorador de archivos
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
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
