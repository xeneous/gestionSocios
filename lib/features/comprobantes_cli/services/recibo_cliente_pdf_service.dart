import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/numero_a_letras.dart';

/// Servicio para generar PDFs de recibos de cobranza a clientes
class ReciboClientePdfService {
  final SupabaseClient _supabase;

  ReciboClientePdfService(this._supabase);

  /// Genera un PDF del recibo de cobranza
  ///
  /// Parámetros:
  /// - idTransaccion: ID del recibo en ven_cli_header
  ///
  /// Retorna el documento PDF generado
  Future<pw.Document> generarReciboPdf({
    required int idTransaccion,
  }) async {
    // 1. Obtener datos del recibo
    final reciboData = await _supabase
        .from('ven_cli_header')
        .select('*, clientes(*)')
        .eq('id_transaccion', idTransaccion)
        .single();

    final numeroRecibo = reciboData['comprobante'] as int;
    final fechaRecibo = DateTime.parse(reciboData['fecha'] as String);
    final totalCobrado = (reciboData['total_importe'] as num).toDouble();
    final clienteId = reciboData['cliente'] as int;

    // 2. Obtener datos del cliente
    final clienteData = reciboData['clientes'] as Map<String, dynamic>?;
    final nombreCliente = clienteData?['razon_social'] as String? ?? 'Cliente $clienteId';
    final cuitCliente = clienteData?['cuit'] as String? ?? '';
    final domicilioCliente = clienteData?['domicilio'] as String? ?? '';

    // 3. Obtener imputaciones (qué facturas se cobraron)
    final imputacionesData = await _supabase
        .from('notas_imputacion')
        .select('*')
        .eq('id_operacion', idTransaccion)
        .eq('tipo_operacion', 2);

    final transaccionesList = <Map<String, dynamic>>[];
    for (final imp in imputacionesData as List) {
      // Obtener datos del comprobante cobrado
      final idTransaccionCobrada = imp['id_transaccion'] as int;
      final compCobrado = await _supabase
          .from('ven_cli_header')
          .select('*, tip_vent_mod_header(*)')
          .eq('id_transaccion', idTransaccionCobrada)
          .single();

      final tipoData = compCobrado['tip_vent_mod_header'] as Map<String, dynamic>?;
      transaccionesList.add({
        'tipo_comprobante': tipoData?['comprobante'] ?? 'FC',
        'nro_comprobante': compCobrado['nro_comprobante'] as String? ?? '',
        'fecha': compCobrado['fecha'] as String?,
        'fecha1_venc': compCobrado['fecha1_venc'] as String?,
        'importe_total': (compCobrado['total_importe'] as num).toDouble(),
        'monto_cobrado': (imp['importe'] as num).toDouble(),
      });
    }

    // 4. Obtener items del recibo (formas de pago)
    final itemsData = await _supabase
        .from('ven_cli_items')
        .select('*')
        .eq('id_transaccion', idTransaccion);

    final formasPagoList = <Map<String, dynamic>>[];
    for (final item in itemsData as List) {
      formasPagoList.add({
        'descripcion': item['detalle'] as String? ?? 'Forma de pago',
        'monto': (item['importe'] as num).toDouble(),
      });
    }

    // Si no hay items, obtener de valores_tesoreria
    if (formasPagoList.isEmpty) {
      final valoresData = await _supabase
          .from('valores_tesoreria')
          .select('*, conceptos_tesoreria(*)')
          .eq('numero_interno', numeroRecibo)
          .eq('tipo_entidad', 'CLI')
          .eq('id_entidad', clienteId);

      for (final valor in valoresData as List) {
        final concepto = valor['conceptos_tesoreria'] as Map<String, dynamic>?;
        formasPagoList.add({
          'descripcion': concepto?['descripcion'] as String? ?? 'Forma de pago',
          'monto': (valor['importe'] as num).toDouble(),
        });
      }
    }

    // 5. Generar PDF
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
                          'REC Nº $numeroRecibo',
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

              // Datos del cliente
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
                      'Cliente Nº: $clienteId',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Razón Social: $nombreCliente',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (cuitCliente.isNotEmpty)
                      pw.Text(
                        'CUIT: $cuitCliente',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (domicilioCliente.isNotEmpty)
                      pw.Text(
                        'Domicilio: $domicilioCliente',
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

              // Tabla de comprobantes cobrados
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
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Tipo', isHeader: true),
                      _buildTableCell('Nro. Comprobante', isHeader: true),
                      _buildTableCell('Fecha', isHeader: true),
                      _buildTableCell('Importe',
                          isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('Cobrado',
                          isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  // Rows
                  ...transaccionesList.map((t) {
                    final fecha = t['fecha'] != null
                        ? dateFormat.format(DateTime.parse(t['fecha']))
                        : '-';
                    final importe =
                        '\$${(t['importe_total'] as double).toStringAsFixed(2)}';
                    final cobrado =
                        '\$${(t['monto_cobrado'] as double).toStringAsFixed(2)}';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(t['tipo_comprobante']),
                        _buildTableCell(t['nro_comprobante']),
                        _buildTableCell(fecha),
                        _buildTableCell(importe, align: pw.TextAlign.right),
                        _buildTableCell(cobrado, align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 16),

              // Formas de pago
              pw.Text(
                'FORMA DE PAGO:',
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
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Descripción', isHeader: true),
                      _buildTableCell('Monto',
                          isHeader: true, align: pw.TextAlign.right),
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
                  }),
                  // Total
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableCell('TOTAL',
                          isHeader: true, align: pw.TextAlign.right),
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

  /// Abre el diálogo de impresión
  Future<void> imprimirRecibo(pw.Document pdf) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  /// Comparte el PDF
  Future<void> compartirRecibo({
    required pw.Document pdf,
    required int numeroRecibo,
    required String nombreCliente,
  }) async {
    final nombreLimpio = nombreCliente
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();

    final fileName = 'rec_${numeroRecibo}_$nombreLimpio.pdf';

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: fileName,
    );
  }
}
