import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;

import '../../models/debito_automatico_item.dart';
import '../../models/presentacion_config.dart';
import '../../providers/debitos_automaticos_provider.dart';
import '../../services/presentacion_tarjetas_service.dart';
import '../../../socios/providers/tarjetas_provider.dart';

class DebitosAutomaticosPage extends ConsumerStatefulWidget {
  const DebitosAutomaticosPage({super.key});

  @override
  ConsumerState<DebitosAutomaticosPage> createState() =>
      _DebitosAutomaticosPageState();
}

class _DebitosAutomaticosPageState
    extends ConsumerState<DebitosAutomaticosPage> {
  DateTime _fechaSeleccionada = DateTime.now();
  int? _tarjetaSeleccionada;
  bool _mostrarVistaPrevia = false;

  @override
  Widget build(BuildContext context) {
    final tarjetasAsync = ref.watch(tarjetasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentación Débitos Automáticos'),
        actions: [
          if (_mostrarVistaPrevia)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _mostrarVistaPrevia = false;
                });
              },
              tooltip: 'Nueva consulta',
            ),
        ],
      ),
      body: Column(
        children: [
          // Panel de filtros
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtros',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Selector de fecha (mes/año)
                      Expanded(
                        child: InkWell(
                          onTap: () => _seleccionarFecha(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Período',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_month),
                            ),
                            child: Text(
                              DateFormat('MM/yyyy').format(_fechaSeleccionada),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Selector de tarjeta
                      Expanded(
                        flex: 2,
                        child: tarjetasAsync.when(
                          data: (tarjetas) => DropdownButtonFormField<int?>(
                            initialValue: _tarjetaSeleccionada,
                            decoration: const InputDecoration(
                              labelText: 'Tarjeta',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.credit_card),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Todas las tarjetas'),
                              ),
                              ...tarjetas.map(
                                (tarjeta) => DropdownMenuItem<int?>(
                                  value: tarjeta.id,
                                  child: Text(tarjeta.descripcion),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _tarjetaSeleccionada = value;
                              });
                            },
                          ),
                          loading: () => DropdownButtonFormField<int?>(
                            decoration: const InputDecoration(
                              labelText: 'Tarjeta',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.credit_card),
                            ),
                            items: const [],
                            onChanged: null,
                          ),
                          error: (error, _) => TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Tarjeta',
                              border: OutlineInputBorder(),
                              errorText: 'Error al cargar tarjetas',
                              prefixIcon: Icon(Icons.credit_card),
                            ),
                            enabled: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Botón Ver Vista Previa
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _mostrarVistaPrevia = true;
                          });
                        },
                        icon: const Icon(Icons.preview),
                        label: const Text('Ver Vista Previa'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Contenido: Vista previa o mensaje
          Expanded(
            child: _mostrarVistaPrevia
                ? _buildVistaPrevia()
                : _buildMensajeInicial(),
          ),
        ],
      ),
    );
  }

  Widget _buildMensajeInicial() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Seleccione el período y tarjeta',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Luego presione "Ver Vista Previa"',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVistaPrevia() {
    // Calcular anioMes del período seleccionado
    final anioMes = _fechaSeleccionada.year * 100 + _fechaSeleccionada.month;

    // Obtener datos según filtros
    final filtro = FiltroDebitosParams(
      anioMes: anioMes,
      tarjetaId: _tarjetaSeleccionada,
    );

    final movimientosAsync = ref.watch(movimientosPendientesProvider(filtro));
    final estadisticasAsync = ref.watch(estadisticasDebitosProvider(filtro));

    return Column(
      children: [
        // Panel de estadísticas
        estadisticasAsync.when(
          data: (stats) => _buildEstadisticas(stats),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Grilla de datos
        Expanded(
          child: movimientosAsync.when(
            data: (movimientos) => _buildDataTable(movimientos),
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
                      setState(() {
                        _mostrarVistaPrevia = false;
                      });
                    },
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Botón de ejecutar presentación
        movimientosAsync.when(
          data: (movimientos) {
            if (movimientos.isEmpty) return const SizedBox.shrink();

            // Solo mostrar si hay tarjetas válidas
            final tarjetasValidas =
                movimientos.where((m) => m.tarjetaValida).toList();
            if (tarjetasValidas.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'No hay movimientos con tarjetas válidas para procesar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border(
                  top: BorderSide(color: Colors.green.shade200, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tarjetasValidas.length} movimientos listos para procesar',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _generarPDF(tarjetasValidas),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Generar PDF'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _ejecutarPresentacion(tarjetasValidas),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Ejecutar Presentación'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildEstadisticas(Map<String, dynamic> stats) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.people,
              label: 'Total Socios',
              value: stats['total_registros'].toString(),
              color: Colors.blue,
            ),
            _buildStatItem(
              icon: Icons.check_circle,
              label: 'Tarjetas Válidas',
              value: stats['tarjetas_validas'].toString(),
              color: Colors.green,
            ),
            _buildStatItem(
              icon: Icons.error,
              label: 'Tarjetas Inválidas',
              value: stats['tarjetas_invalidas'].toString(),
              color: Colors.red,
            ),
            _buildStatItem(
              icon: Icons.attach_money,
              label: 'Total a Debitar',
              value: currencyFormat.format(stats['total_importe']),
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(List<DebitoAutomaticoItem> movimientos) {
    if (movimientos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay movimientos pendientes para el período seleccionado',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return SingleChildScrollView(
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
                  'Nº Socio',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
                  'Número Tarjeta',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Estado',
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
            ],
            rows: movimientos.map((item) {
              final tarjetaValida = item.tarjetaValida;

              return DataRow(
                cells: [
                  DataCell(Text(item.socioId.toString())),
                  DataCell(Text(item.apellido)),
                  DataCell(Text(item.nombre)),
                  DataCell(
                    Text(
                      item.numeroTarjetaEnmascarado,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: tarjetaValida ? null : Colors.red,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tarjetaValida ? Icons.check_circle : Icons.error,
                          color: tarjetaValida ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tarjetaValida ? 'Válida' : 'Inválida',
                          style: TextStyle(
                            color: tarjetaValida ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      currencyFormat.format(item.importe),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final fechaActual = _fechaSeleccionada;

    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaActual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Seleccionar período',
      fieldLabelText: 'Fecha',
      initialDatePickerMode: DatePickerMode.year,
    );

    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
        _mostrarVistaPrevia = false; // Reset vista previa
      });
    }
  }

  Future<void> _ejecutarPresentacion(
      List<DebitoAutomaticoItem> movimientos) async {
    // Confirmar con el usuario
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Ejecución'),
        content: Text(
          '¿Está seguro que desea procesar ${movimientos.length} débitos automáticos?\n\n'
          'Esta acción generará el archivo de presentación para la tarjeta seleccionada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      // Importar servicio
      final service = PresentacionTarjetasService();
      
      // Determinar tipo de tarjeta (Visa o Mastercard)
      final esVisa = _tarjetaSeleccionada == PresentacionConfig.visaTarjetaId;
      
      // Generar archivo según tipo de tarjeta
      final String contenidoArchivo;
      final String nombreArchivo;
      
      if (esVisa) {
        contenidoArchivo = service.generarArchivoVisa(movimientos, _fechaSeleccionada);
        nombreArchivo = 'Visamov_${DateFormat('yyyyMMdd').format(_fechaSeleccionada)}.txt';
      } else {
        contenidoArchivo = service.generarArchivoMastercard(movimientos, _fechaSeleccionada);
        nombreArchivo = 'Pesos_${DateFormat('yyyyMMdd').format(_fechaSeleccionada)}.txt';
      }

      // Descargar archivo
      if (kIsWeb) {
        _descargarArchivoWeb(contenidoArchivo, nombreArchivo);
      } else {
        await _descargarArchivoDesktop(contenidoArchivo, nombreArchivo);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Archivo generado exitosamente: $nombreArchivo\n'
              '${movimientos.length} movimientos procesados',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // NUEVO: Preguntar si desea registrar contablemente
        final registrar = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Registrar Presentación'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Desea registrar contablemente esta presentación de débito automático?',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  'Esto creará:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Comprobantes DA en cuenta corriente'),
                Text('• Actualización de cancelado en CS'),
                Text('• Asiento contable tipo 6'),
                Text('• Trazabilidad completa'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No registrar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Sí, Registrar'),
              ),
            ],
          ),
        );

        if (registrar == true && mounted) {
          await _registrarPresentacion(movimientos, esVisa);
        }

        // Resetear vista
        setState(() {
          _mostrarVistaPrevia = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error al generar presentación: $e');
      print(stackTrace);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar archivo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Descarga archivo en Flutter Web usando blob
  void _descargarArchivoWeb(String contenido, String nombreArchivo) {
    final bytes = utf8.encode(contenido);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', nombreArchivo)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Descarga archivo en Desktop/Mobile
  Future<void> _descargarArchivoDesktop(String contenido, String nombreArchivo) async {
    final directory = await getDownloadsDirectory();
    if (directory == null) {
      throw Exception('No se pudo acceder al directorio de descargas');
    }

    final filePath = '${directory.path}/$nombreArchivo';
    final file = File(filePath);
    await file.writeAsString(contenido);
  }

  /// Genera un PDF con la previsualización de la presentación
  Future<void> _generarPDF(List<DebitoAutomaticoItem> movimientos) async {
    try {
      // Mostrar indicador de carga
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generando PDF...'),
              ],
            ),
          ),
        );
      }

      // Importar paquetes necesarios
      final pdf = pw.Document();
      final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

      // Obtener nombre de la tarjeta
      final tarjetasAsync = ref.read(tarjetasProvider);
      String nombreTarjeta = 'Débito Automático';
      if (tarjetasAsync.hasValue && _tarjetaSeleccionada != null) {
        final tarjeta = tarjetasAsync.value!.firstWhere(
          (t) => t.id == _tarjetaSeleccionada,
          orElse: () => tarjetasAsync.value!.first,
        );
        nombreTarjeta = tarjeta.descripcion;
      }

      // Calcular estadísticas
      final totalSocios = movimientos.map((m) => m.socioId).toSet().length;
      final totalImporte = movimientos.fold<double>(0.0, (sum, item) => sum + item.importe);

      // Crear página del PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Título
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Presentación Débito Automático',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '$nombreTarjeta - Período: ${DateFormat('MM/yyyy').format(_fechaSeleccionada)}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Fecha generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Estadísticas
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Total Socios', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(totalSocios.toString(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Total Registros', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(movimientos.length.toString(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Importe Total', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(currencyFormat.format(totalImporte), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Tabla de movimientos
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 25,
              cellAlignments: {
                0: pw.Alignment.centerLeft,   // Socio
                1: pw.Alignment.centerLeft,   // Nombre
                2: pw.Alignment.center,       // Tarjeta
                3: pw.Alignment.centerLeft,   // Tipo Comp
                4: pw.Alignment.center,       // Doc Nro
                5: pw.Alignment.centerRight,  // Importe
              },
              headers: ['Socio', 'Nombre', 'Tarjeta', 'Tipo', 'Doc. Nro', 'Importe'],
              data: movimientos.map((item) {
                final nombreCompleto = '${item.apellido}, ${item.nombre}';
                final tarjeta = item.numeroTarjetaEnmascarado;
                return [
                  item.socioId.toString(),
                  nombreCompleto.length > 30 ? nombreCompleto.substring(0, 30) : nombreCompleto,
                  tarjeta.length > 19 ? tarjeta.substring(0, 19) : tarjeta,
                  item.tipoComprobante,
                  item.documentoNumero,
                  currencyFormat.format(item.importe),
                ];
              }).toList(),
            ),
          ],
        ),
      );

      // Generar bytes del PDF
      final pdfBytes = await pdf.save();

      // Cerrar indicador de carga
      if (mounted) {
        Navigator.pop(context);
      }

      // Descargar PDF
      final nombreArchivo = 'Presentacion_DA_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      if (kIsWeb) {
        // Descarga en Web
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', nombreArchivo)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Descarga en Desktop/Mobile
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('No se pudo acceder al directorio de descargas');
        }
        final filePath = '${directory.path}/$nombreArchivo';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generado exitosamente: $nombreArchivo'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error al generar PDF: $e');
      print(stackTrace);

      // Cerrar indicador de carga si está abierto
      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Registra contablemente la presentación de débito automático
  Future<void> _registrarPresentacion(
    List<DebitoAutomaticoItem> movimientos,
    bool esVisa,
  ) async {
    try {
      // Mostrar indicador de carga
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Registrando presentación...'),
              ],
            ),
          ),
        );
      }

      // Obtener el servicio
      final service = ref.read(debitosAutomaticosServiceProvider);

      // Calcular parámetros
      final anioMes = _fechaSeleccionada.year * 100 + _fechaSeleccionada.month;
      final nombreTarjeta = esVisa ? 'Visa' : 'Mastercard';

      // Registrar la presentación
      final resultado = await service.registrarPresentacionDebitoAutomatico(
        items: movimientos,
        anioMes: anioMes,
        fechaPresentacion: _fechaSeleccionada,
        nombreTarjeta: nombreTarjeta,
        operadorId: null, // TODO: Obtener del auth provider si es necesario
      );

      // Cerrar indicador de carga
      if (mounted) {
        Navigator.pop(context);

        // Mostrar éxito
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('Registro Exitoso'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La presentación de débito automático ha sido registrada correctamente.',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Operación ID: ${resultado['operacion_id']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Asiento generado: ${resultado['numero_asiento']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Socios procesados: ${movimientos.map((m) => m.socioId).toSet().length}',
                ),
                Text(
                  'Total presentado: \$${movimientos.fold<double>(0.0, (sum, item) => sum + item.importe).toStringAsFixed(2)}',
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error al registrar presentación: $e');
      print(stackTrace);

      // Cerrar indicador de carga si está abierto
      if (mounted) {
        Navigator.pop(context);

        // Mostrar error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Text('Error al Registrar'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No se pudo registrar la presentación:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    e.toString(),
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'El archivo ya fue generado, pero no se registró contablemente. '
                  'Puede intentar registrarlo nuevamente más tarde.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
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
    }
  }

}
