import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../../../cuentas_corrientes/services/recibo_pdf_service.dart';
import '../../../comprobantes_cli/services/recibo_cliente_pdf_service.dart';
import '../../../comprobantes_prov/services/orden_pago_pdf_service.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class ReimpresionPage extends ConsumerStatefulWidget {
  const ReimpresionPage({super.key});

  @override
  ConsumerState<ReimpresionPage> createState() => _ReimpresionPageState();
}

class _ReimpresionPageState extends ConsumerState<ReimpresionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Filtros compartidos
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  final _nroController = TextEditingController();

  bool _buscando = false;
  List<Map<String, dynamic>> _resultadosOP = [];
  List<Map<String, dynamic>> _resultadosCob = [];

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nroController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BÚSQUEDA
  // ─────────────────────────────────────────────

  Future<void> _buscar() async {
    final nroText = _nroController.text.trim();
    final int? nroFiltro = nroText.isNotEmpty ? int.tryParse(nroText) : null;

    if (_fechaDesde == null && _fechaHasta == null && nroFiltro == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese al menos un criterio de búsqueda'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _buscando = true);

    try {
      final supabase = ref.read(supabaseProvider);

      if (_tabController.index == 0) {
        await _buscarOP(supabase, nroFiltro);
      } else {
        await _buscarCobranzas(supabase, nroFiltro);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _buscarOP(SupabaseClient supabase, int? nroFiltro) async {
    var query = supabase
        .from('comp_prov_header')
        .select('id_transaccion, comprobante, fecha, total_importe, proveedores(razon_social)')
        .eq('tipo_comprobante', 0); // 0 = OP

    if (_fechaDesde != null) {
      query = query.gte('fecha', _fechaDesde!.toIso8601String().split('T')[0]);
    }
    if (_fechaHasta != null) {
      query = query.lte('fecha', _fechaHasta!.toIso8601String().split('T')[0]);
    }
    if (nroFiltro != null) {
      query = query.eq('comprobante', nroFiltro);
    }

    final response = await query.order('comprobante', ascending: false).limit(200);
    setState(() => _resultadosOP = (response as List).cast<Map<String, dynamic>>());
  }

  Future<void> _buscarCobranzas(SupabaseClient supabase, int? nroFiltro) async {
    var query = supabase
        .from('operaciones_contables')
        .select('id, numero_comprobante, fecha, total, tipo_operacion, entidad_id')
        .inFilter('tipo_operacion', ['COBRANZA_SOCIO', 'COBRANZA_PROFESIONAL', 'COBRANZA_SPONSOR']);

    if (_fechaDesde != null) {
      query = query.gte('fecha', _fechaDesde!.toIso8601String().split('T')[0]);
    }
    if (_fechaHasta != null) {
      query = query.lte('fecha', _fechaHasta!.toIso8601String().split('T')[0]);
    }
    if (nroFiltro != null) {
      query = query.eq('numero_comprobante', nroFiltro);
    }

    final response = await query.order('numero_comprobante', ascending: false).limit(200);
    setState(() => _resultadosCob = (response as List).cast<Map<String, dynamic>>());
  }

  // ─────────────────────────────────────────────
  // REIMPRESIÓN
  // ─────────────────────────────────────────────

  Future<void> _confirmarYReimprimir({
    required String titulo,
    required Future<void> Function() accion,
  }) async {
    // Pedir contraseña
    final claveController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reimprimir $titulo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingrese la clave de autorización:'),
            const SizedBox(height: 12),
            TextField(
              controller: claveController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Clave',
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (ok != true) return;

    const adminClave = 'SAO2026';
    if (claveController.text != adminClave) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clave incorrecta'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
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
      await accion();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reimprimirOP(Map<String, dynamic> row) async {
    final idTransaccion = row['id_transaccion'] as int;
    final nro = row['comprobante'] as int;

    await _confirmarYReimprimir(
      titulo: 'OP Nro. $nro',
      accion: () async {
        final supabase = ref.read(supabaseProvider);
        final pdfService = OrdenPagoPdfService(supabase);
        final pdf = await pdfService.generarOrdenPagoPdf(idTransaccion: idTransaccion);

        if (kIsWeb) {
          final bytes = await pdf.save();
          final blob = html.Blob([bytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute('download', 'OP_$nro.pdf')
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          await pdfService.imprimirOrdenPago(pdf);
        }
      },
    );
  }

  Future<void> _reimprimirCobranza(Map<String, dynamic> row) async {
    final tipoOp = row['tipo_operacion'] as String;
    final nroRecibo = row['numero_comprobante'] as int;
    final idTransaccion = row['id'] as int;

    await _confirmarYReimprimir(
      titulo: 'Recibo Nro. $nroRecibo',
      accion: () async {
        final supabase = ref.read(supabaseProvider);

        if (tipoOp == 'COBRANZA_SPONSOR') {
          final pdfService = ReciboClientePdfService(supabase);
          final pdf = await pdfService.generarReciboPdf(idTransaccion: idTransaccion);
          if (kIsWeb) {
            final bytes = await pdf.save();
            final blob = html.Blob([bytes], 'application/pdf');
            final url = html.Url.createObjectUrlFromBlob(blob);
            html.AnchorElement(href: url)
              ..setAttribute('download', 'Recibo_$nroRecibo.pdf')
              ..click();
            html.Url.revokeObjectUrl(url);
          } else {
            await pdfService.imprimirRecibo(pdf);
          }
        } else {
          final pdfService = ReciboPdfService(supabase);
          final pdf = await pdfService.generarReciboPdf(numeroRecibo: nroRecibo);
          if (kIsWeb) {
            final bytes = await pdf.save();
            final blob = html.Blob([bytes], 'application/pdf');
            final url = html.Url.createObjectUrlFromBlob(blob);
            html.AnchorElement(href: url)
              ..setAttribute('download', 'Recibo_$nroRecibo.pdf')
              ..click();
            html.Url.revokeObjectUrl(url);
          } else {
            await pdfService.imprimirRecibo(pdf);
          }
        }
      },
    );
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reimpresión'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {
            _resultadosOP = [];
            _resultadosCob = [];
          }),
          tabs: const [
            Tab(icon: Icon(Icons.payment), text: 'Órdenes de Pago'),
            Tab(icon: Icon(Icons.receipt), text: 'Cobranzas'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFiltros(),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildTablaOP(),
                _buildTablaCobranzas(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Fecha Desde
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaDesde ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _fechaDesde = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Desde',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                  suffixIcon: _fechaDesde != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _fechaDesde = null),
                        )
                      : null,
                ),
                child: Text(
                  _fechaDesde != null ? _dateFormat.format(_fechaDesde!) : 'Sin filtro',
                  style: TextStyle(
                    color: _fechaDesde != null ? null : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Fecha Hasta
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaHasta ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _fechaHasta = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Hasta',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                  suffixIcon: _fechaHasta != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _fechaHasta = null),
                        )
                      : null,
                ),
                child: Text(
                  _fechaHasta != null ? _dateFormat.format(_fechaHasta!) : 'Sin filtro',
                  style: TextStyle(
                    color: _fechaHasta != null ? null : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Número
          SizedBox(
            width: 160,
            child: TextField(
              controller: _nroController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nro. comprobante',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag, size: 18),
              ),
              onSubmitted: (_) => _buscar(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _buscando ? null : _buscar,
            icon: _buscando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTablaOP() {
    if (_resultadosOP.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Ingrese filtros y presione Buscar', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.orange.shade50),
        columns: const [
          DataColumn(label: Text('Nro. OP', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Proveedor', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _resultadosOP.map((row) {
          final proveedor = row['proveedores'] as Map<String, dynamic>?;
          final razonSocial = proveedor?['razon_social'] as String? ?? 'Proveedor';
          final fecha = DateTime.tryParse(row['fecha'] as String? ?? '');
          final total = (row['total_importe'] as num?)?.toDouble() ?? 0.0;

          return DataRow(cells: [
            DataCell(Text(
              row['comprobante'].toString().padLeft(6, '0'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            )),
            DataCell(Text(razonSocial)),
            DataCell(Text(fecha != null ? _dateFormat.format(fecha) : '-')),
            DataCell(Text(_currencyFormat.format(total))),
            DataCell(
              IconButton(
                icon: const Icon(Icons.print, color: Colors.teal),
                tooltip: 'Reimprimir',
                onPressed: () => _reimprimirOP(row),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildTablaCobranzas() {
    if (_resultadosCob.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Ingrese filtros y presione Buscar', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
        columns: const [
          DataColumn(label: Text('Nro. Recibo', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _resultadosCob.map((row) {
          final tipoOp = row['tipo_operacion'] as String;
          final tipoLabel = tipoOp == 'COBRANZA_SOCIO'
              ? 'Socio'
              : tipoOp == 'COBRANZA_PROFESIONAL'
                  ? 'Profesional'
                  : 'Sponsor';
          final fecha = DateTime.tryParse(row['fecha'] as String? ?? '');
          final total = (row['total'] as num?)?.toDouble() ?? 0.0;

          return DataRow(cells: [
            DataCell(Text(
              (row['numero_comprobante'] as int).toString().padLeft(6, '0'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            )),
            DataCell(Chip(
              label: Text(tipoLabel, style: const TextStyle(fontSize: 11)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )),
            DataCell(Text(fecha != null ? _dateFormat.format(fecha) : '-')),
            DataCell(Text(_currencyFormat.format(total))),
            DataCell(
              IconButton(
                icon: const Icon(Icons.print, color: Colors.teal),
                tooltip: 'Reimprimir',
                onPressed: () => _reimprimirCobranza(row),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}
