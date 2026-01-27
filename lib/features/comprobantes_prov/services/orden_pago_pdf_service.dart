import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/numero_a_letras.dart';

/// Servicio para generar PDFs de órdenes de pago a proveedores
class OrdenPagoPdfService {
  final SupabaseClient _supabase;

  OrdenPagoPdfService(this._supabase);

  /// Genera un PDF de la orden de pago
  ///
  /// Parámetros:
  /// - idTransaccion: ID de la orden de pago en comp_prov_header
  ///
  /// Retorna el documento PDF generado
  Future<pw.Document> generarOrdenPagoPdf({
    required int idTransaccion,
  }) async {
    // 1. Obtener datos de la orden de pago
    final opData = await _supabase
        .from('comp_prov_header')
        .select('*, proveedores(*)')
        .eq('id_transaccion', idTransaccion)
        .single();

    final numeroOP = opData['comprobante'] as int;
    final fechaOP = DateTime.parse(opData['fecha'] as String);
    final totalPagado = (opData['total_importe'] as num).toDouble();
    final proveedorId = opData['proveedor'] as int;

    // 2. Obtener datos del proveedor
    final proveedorData = opData['proveedores'] as Map<String, dynamic>?;
    final nombreProveedor = proveedorData?['razon_social'] as String? ?? 'Proveedor $proveedorId';
    final cuitProveedor = proveedorData?['cuit'] as String? ?? '';
    final domicilioProveedor = proveedorData?['domicilio'] as String? ?? '';

    // 3. Obtener imputaciones (qué facturas se pagaron)
    final imputacionesData = await _supabase
        .from('notas_imputacion')
        .select('*, comp_prov_header!id_transaccion(*)')
        .eq('id_operacion', idTransaccion)
        .eq('tipo_operacion', 1);

    final transaccionesList = <Map<String, dynamic>>[];
    for (final imp in imputacionesData as List) {
      // Obtener datos del comprobante pagado
      final idTransaccionPagada = imp['id_transaccion'] as int;
      final compPagado = await _supabase
          .from('comp_prov_header')
          .select('*, tip_comp_mod_header(*)')
          .eq('id_transaccion', idTransaccionPagada)
          .single();

      final tipoData = compPagado['tip_comp_mod_header'] as Map<String, dynamic>?;
      transaccionesList.add({
        'tipo_comprobante': tipoData?['comprobante'] ?? 'FC',
        'nro_comprobante': compPagado['nro_comprobante'] as String? ?? '',
        'fecha': compPagado['fecha'] as String?,
        'fecha1_venc': compPagado['fecha1_venc'] as String?,
        'importe_total': (compPagado['total_importe'] as num).toDouble(),
        'monto_pagado': (imp['importe'] as num).toDouble(),
      });
    }

    // 4. Obtener items de la OP (formas de pago)
    final itemsData = await _supabase
        .from('comp_prov_items')
        .select('*, conceptos_tesoreria:cuenta(*)')
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
          .eq('numero_interno', numeroOP)
          .eq('tipo_entidad', 'PRO')
          .eq('id_entidad', proveedorId);

      for (final valor in valoresData as List) {
        final concepto = valor['conceptos_tesoreria'] as Map<String, dynamic>?;
        formasPagoList.add({
          'descripcion': concepto?['descripcion'] as String? ?? 'Forma de pago',
          'monto': ((valor['importe'] as num).toDouble()).abs(),
        });
      }
    }

    // 5. Generar PDF
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Convertir total a letras
    final totalEnLetras = NumeroALetras.convertir(totalPagado);

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
                        'ORDEN DE PAGO',
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
                          'OP Nº $numeroOP',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Fecha: ${dateFormat.format(fechaOP)}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // Datos del proveedor
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PÁGUESE A',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Proveedor Nº: $proveedorId',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Razón Social: $nombreProveedor',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (cuitProveedor.isNotEmpty)
                      pw.Text(
                        'CUIT: $cuitProveedor',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (domicilioProveedor.isNotEmpty)
                      pw.Text(
                        'Domicilio: $domicilioProveedor',
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

              // Tabla de comprobantes pagados
              pw.Text(
                'EN CANCELACIÓN DE:',
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
                      _buildTableCell('Pagado',
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
                    final pagado =
                        '\$${(t['monto_pagado'] as double).toStringAsFixed(2)}';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(t['tipo_comprobante']),
                        _buildTableCell(t['nro_comprobante']),
                        _buildTableCell(fecha),
                        _buildTableCell(importe, align: pw.TextAlign.right),
                        _buildTableCell(pagado, align: pw.TextAlign.right),
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
                        '\$${totalPagado.toStringAsFixed(2)}',
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer con firmas
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(
                    width: 150,
                    child: pw.Column(
                      children: [
                        pw.Divider(),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Firma Autorizada',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 150,
                    child: pw.Column(
                      children: [
                        pw.Divider(),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Recibí Conforme',
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
  Future<void> imprimirOrdenPago(pw.Document pdf) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  /// Comparte el PDF
  Future<void> compartirOrdenPago({
    required pw.Document pdf,
    required int numeroOP,
    required String nombreProveedor,
  }) async {
    final nombreLimpio = nombreProveedor
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();

    final fileName = 'op_${numeroOP}_$nombreLimpio.pdf';

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: fileName,
    );
  }
}
