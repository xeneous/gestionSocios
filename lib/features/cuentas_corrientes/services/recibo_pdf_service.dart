import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/numero_a_letras.dart';

/// Servicio para generar PDFs de recibos de cobranza
class ReciboPdfService {
  final SupabaseClient _supabase;

  ReciboPdfService(this._supabase);

  /// Genera un PDF del recibo de cobranza
  ///
  /// Obtiene todos los datos directamente de la base de datos usando el número de recibo.
  /// Esto garantiza que siempre se muestren los datos correctos y persistidos.
  ///
  /// Parámetros:
  /// - numeroRecibo: Número del recibo a generar
  ///
  /// Retorna el documento PDF generado
  Future<pw.Document> generarReciboPdf({
    required int numeroRecibo,
  }) async {
    // 1. Obtener valores de tesorería del recibo (formas de pago)
    final valoresTesoreria = await _supabase
        .from('valores_tesoreria')
        .select('*, conceptos_tesoreria(*)')
        .eq('numero_interno', numeroRecibo)
        .eq('tipo_movimiento', 1); // 1 = Ingreso/Cobro

    if (valoresTesoreria.isEmpty) {
      throw Exception('No se encontró el recibo $numeroRecibo');
    }

    // 2. Obtener el registro COB para saber el socio
    final registroCOB = await _supabase
        .from('cuentas_corrientes')
        .select('socio_id, fecha')
        .eq('tipo_comprobante', 'COB')
        .eq('documento_numero', numeroRecibo.toString())
        .single();

    final socioId = registroCOB['socio_id'] as int;
    final fechaRecibo = DateTime.parse(registroCOB['fecha']);

    // 3. Obtener datos del socio
    final socioData = await _supabase
        .from('socios')
        .select('id, apellido, nombre, domicilio, telefono')
        .eq('id', socioId)
        .single();

    final nombreCompleto = '${socioData['apellido']}, ${socioData['nombre']}'.trim();
    final domicilio = socioData['domicilio'] as String? ?? '';
    final telefono = socioData['telefono'] as String? ?? '';

    // 4. Preparar formas de pago desde valores_tesoreria
    final formasPagoList = <Map<String, dynamic>>[];
    double totalCobrado = 0;

    for (final valor in valoresTesoreria) {
      final importe = (valor['importe'] as num).toDouble();
      totalCobrado += importe;

      formasPagoList.add({
        'descripcion': valor['conceptos_tesoreria']['descripcion'] as String,
        'monto': importe,
      });
    }

    // 5. Obtener transacciones que fueron pagadas con este recibo
    // Buscamos en observaciones de asientos que contengan el número de recibo
    final transaccionesList = <Map<String, dynamic>>[];

    // Obtener asiento items que referencian este recibo en HABER
    final asientoItems = await _supabase
        .from('asientos_items')
        .select('observacion, haber')
        .ilike('observacion', '%Recibo Nro. $numeroRecibo%')
        .gt('haber', 0);

    // Extraer información de las observaciones
    for (final item in asientoItems) {
      final observacion = item['observacion'] as String?;
      final haber = (item['haber'] as num).toDouble();

      if (observacion != null && observacion.contains('-')) {
        // Formato: "Recibo Nro. 123 - MAE 202512"
        final partes = observacion.split(' - ');
        if (partes.length >= 2) {
          final comprobante = partes[1].trim();
          transaccionesList.add({
            'tipo_comprobante': comprobante.split(' ').first,
            'documento_numero': comprobante.split(' ').skip(1).join(' '),
            'importe_total': haber, // Aproximación
            'fecha': null,
            'vencimiento': null,
            'monto_pagado': haber,
          });
        }
      }
    }

    // 6. Generar PDF
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Convertir total a letras
    final totalEnLetras = NumeroALetras.convertir(totalCobrado);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SOCIEDAD ARGENTINA DE OFTALMOLOGÍA',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'RECIBO DE COBRANZA',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 2),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Nº $numeroRecibo',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Fecha: ${dateFormat.format(fechaRecibo)}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // Datos del socio
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RECIBIMOS DE',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Socio Nº: $socioId',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Nombre: $nombreCompleto',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (domicilio.isNotEmpty)
                      pw.Text(
                        'Domicilio: $domicilio',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (telefono.isNotEmpty)
                      pw.Text(
                        'Teléfono: $telefono',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Total en letras
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LA SUMA DE:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      totalEnLetras.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Tabla de transacciones pagadas
              pw.Text(
                'EN CONCEPTO DE:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Comprobante', isHeader: true),
                      _buildTableCell('Fecha', isHeader: true),
                      _buildTableCell('Vencimiento', isHeader: true),
                      _buildTableCell('Importe', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('Pagado', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  // Rows
                  ...transaccionesList.map((t) {
                    final comprobante = '${t['tipo_comprobante']} ${t['documento_numero'] ?? ''}';
                    final fecha = t['fecha'] != null
                        ? dateFormat.format(DateTime.parse(t['fecha']))
                        : '-';
                    final vencimiento = t['vencimiento'] != null
                        ? dateFormat.format(DateTime.parse(t['vencimiento']))
                        : '-';
                    final importe = '\$${(t['importe_total'] as double).toStringAsFixed(2)}';
                    final pagado = '\$${(t['monto_pagado'] as double).toStringAsFixed(2)}';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(comprobante),
                        _buildTableCell(fecha),
                        _buildTableCell(vencimiento),
                        _buildTableCell(importe, align: pw.TextAlign.right),
                        _buildTableCell(pagado, align: pw.TextAlign.right),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 16),

              // Formas de pago
              pw.Text(
                'FORMAS DE PAGO:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Descripción', isHeader: true),
                      _buildTableCell('Monto', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  // Rows
                  ...formasPagoList.map((fp) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(fp['descripcion']),
                        _buildTableCell(
                          '\$${(fp['monto'] as double).toStringAsFixed(2)}',
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }).toList(),
                  // Total
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableCell('TOTAL', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell(
                        '\$${totalCobrado.toStringAsFixed(2)}',
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer con firma
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Divider(),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Firma y Sello',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Helper para construir celdas de tabla
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  /// Guarda el PDF en el dispositivo y retorna la ruta del archivo
  /// Nombre del archivo: rc_[numero]_[nombre].pdf
  Future<String> guardarPdf({
    required pw.Document pdf,
    required int numeroRecibo,
    required String nombreSocio,
  }) async {
    // Limpiar nombre del socio para usar en nombre de archivo
    final nombreLimpio = nombreSocio
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();

    final fileName = 'rc_${numeroRecibo}_$nombreLimpio.pdf';

    // Obtener directorio de documentos
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');

    // Guardar PDF
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Abre el diálogo de impresión
  Future<void> imprimirRecibo(pw.Document pdf) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  /// Comparte el PDF (permite enviarlo por email, guardar, etc.)
  Future<void> compartirRecibo({
    required pw.Document pdf,
    required int numeroRecibo,
    required String nombreSocio,
  }) async {
    final nombreLimpio = nombreSocio
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();

    final fileName = 'rc_${numeroRecibo}_$nombreLimpio.pdf';

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: fileName,
    );
  }
}
