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
    final observaciones = opData['observaciones'] as String? ?? '';

    // 2. Obtener datos del proveedor
    final proveedorData = opData['proveedores'] as Map<String, dynamic>?;
    final nombreProveedor =
        proveedorData?['razon_social'] as String? ?? 'Proveedor $proveedorId';
    final telefonoProveedor = proveedorData?['telefono'] as String? ?? '';

    // 3. Obtener imputaciones (qué facturas se pagaron)
    final imputacionesData = await _supabase
        .from('notas_imputacion')
        .select('id_operacion, id_transaccion, importe')
        .eq('id_operacion', idTransaccion)
        .eq('tipo_operacion', 1);

    final transaccionesList = <Map<String, dynamic>>[];
    for (final imp in imputacionesData as List) {
      final idTransaccionPagada = imp['id_transaccion'] as int;
      final compPagado = await _supabase
          .from('comp_prov_header')
          .select('tipo_comprobante, nro_comprobante, fecha, total_importe')
          .eq('id_transaccion', idTransaccionPagada)
          .single();

      final tipoCompCodigo = compPagado['tipo_comprobante'] as int?;
      String tipoLabel = 'FC';
      if (tipoCompCodigo != null) {
        final tipoResp = await _supabase
            .from('tip_comp_mod_header')
            .select('comprobante')
            .eq('codigo', tipoCompCodigo)
            .maybeSingle();
        tipoLabel = tipoResp?['comprobante'] as String? ?? 'FC';
      }

      transaccionesList.add({
        'tipo_comprobante': tipoLabel,
        'nro_comprobante': compPagado['nro_comprobante'] as String? ?? '',
        'fecha': compPagado['fecha'] as String?,
        'monto_pagado': (imp['importe'] as num).toDouble(),
      });
    }

    // 4. Obtener formas de pago (items de la OP)
    final itemsData = await _supabase
        .from('comp_prov_items')
        .select('item, detalle, importe')
        .eq('id_transaccion', idTransaccion)
        .order('item');

    final formasPagoList = <Map<String, dynamic>>[];
    for (final item in itemsData as List) {
      formasPagoList.add({
        'descripcion': item['detalle'] as String? ?? 'Forma de pago',
        'monto': ((item['importe'] as num).toDouble()).abs(),
      });
    }

    if (formasPagoList.isEmpty) {
      final valoresData = await _supabase
          .from('valores_tesoreria')
          .select('idconcepto_tesoreria, importe')
          .eq('numero_interno', numeroOP);

      for (final valor in valoresData as List) {
        final conceptoId = valor['idconcepto_tesoreria'] as int?;
        String descripcion = 'Forma de pago';
        if (conceptoId != null) {
          final conceptoResp = await _supabase
              .from('conceptos_tesoreria')
              .select('descripcion')
              .eq('id', conceptoId)
              .maybeSingle();
          descripcion =
              conceptoResp?['descripcion'] as String? ?? 'Forma de pago';
        }
        formasPagoList.add({
          'descripcion': descripcion,
          'monto': ((valor['importe'] as num).toDouble()).abs(),
        });
      }
    }

    // 5. Generar PDF
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat('#,##0.00');
    final totalEnLetras = NumeroALetras.convertir(totalPagado);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header institucional ──
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Sociedad Argentina de Oftalmologia',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Marcelo Torcuato de Alvear 2051, C1122 Cdad. Autónoma de Buenos Aires',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '4373-8826',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'info@sao.org.ar',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // ── Nombre / OP / Fecha ──
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: const pw.BorderSide(),
                    left: const pw.BorderSide(),
                    right: const pw.BorderSide(),
                  ),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'Nombre: $proveedorId  $nombreProveedor',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Text(
                      'Orden de Pago: $numeroOP',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Text(
                      'Fecha: ${dateFormat.format(fechaOP)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Telefono
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: pw.Text(
                  'Telefono: $telefonoProveedor',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),

              pw.SizedBox(height: 10),

              // ── Tabla comprobantes: Emisión | Comprobante | Importe ──
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(80),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FixedColumnWidth(110),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _cell('Emisión', isHeader: true),
                      _cell('Comprobante', isHeader: true),
                      _cell(
                        'Importe',
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  ...transaccionesList.map((t) {
                    final fecha = t['fecha'] != null
                        ? dateFormat
                            .format(DateTime.parse(t['fecha'] as String))
                        : '-';
                    final comprobante =
                        '${t['tipo_comprobante']}  ${t['nro_comprobante']}';
                    return pw.TableRow(
                      children: [
                        _cell(fecha),
                        _cell(comprobante),
                        _cell(
                          currencyFormat.format(t['monto_pagado'] as double),
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }),
                  // Total row
                  pw.TableRow(
                    children: [
                      _cell(''),
                      _cell(
                        'Total:',
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Container(
                          decoration: pw.BoxDecoration(border: pw.Border.all()),
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: pw.Text(
                            currencyFormat.format(totalPagado),
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Son Pesos (borde continuo con la tabla) ──
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: const pw.BorderSide(),
                    right: const pw.BorderSide(),
                    bottom: const pw.BorderSide(),
                  ),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: pw.Text(
                  'Son Pesos: $totalEnLetras',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),

              pw.SizedBox(height: 14),

              // ── Resumen: total + formas de pago ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.SizedBox(),
                  pw.Text(
                    currencyFormat.format(totalPagado),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              ...formasPagoList.map(
                (fp) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        fp['descripcion'] as String,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        currencyFormat.format(fp['monto'] as double),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 14),

              // ── Observaciones ──
              pw.Text(
                'Observaciones:',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (observaciones.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(observaciones, style: const pw.TextStyle(fontSize: 9)),
              ],

              pw.Spacer(),

              // ── Footer firmas ──
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
                          'Recibido',
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
                          'Gerencia',
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

  pw.Widget _cell(
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

  Future<void> imprimirOrdenPago(pw.Document pdf) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  Future<void> compartirOrdenPago({
    required pw.Document pdf,
    required int numeroOP,
    required String nombreProveedor,
  }) async {
    final nombreLimpio = nombreProveedor
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'op_${numeroOP}_$nombreLimpio.pdf',
    );
  }
}
