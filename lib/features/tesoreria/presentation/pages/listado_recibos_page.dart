import 'dart:math' as math;

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../../core/utils/date_picker_utils.dart';

// ---------------------------------------------------------------------------
// Modelo
// ---------------------------------------------------------------------------

/// Una fila por cada valor (forma de pago) ingresado en un recibo.
class ReciboListadoFila {
  final DateTime fecha;
  final int? numeroRecibo;
  final String tipo; // 'Socio' | 'Profesional'
  final String nombre;
  final int? cuenta;
  final String cuentaDescripcion;
  final String formaPago;
  final double importe;

  const ReciboListadoFila({
    required this.fecha,
    required this.numeroRecibo,
    required this.tipo,
    required this.nombre,
    required this.cuenta,
    required this.cuentaDescripcion,
    required this.formaPago,
    required this.importe,
  });
}

// ---------------------------------------------------------------------------
// Params + Provider
// ---------------------------------------------------------------------------

enum TipoListadoRecibos { todos, socios, profesionales, sponsors }

class ListadoRecibosParams {
  final DateTime fechaDesde;
  final DateTime fechaHasta;
  final TipoListadoRecibos tipo;

  const ListadoRecibosParams({
    required this.fechaDesde,
    required this.fechaHasta,
    required this.tipo,
  });

  @override
  bool operator ==(Object other) =>
      other is ListadoRecibosParams &&
      fechaDesde == other.fechaDesde &&
      fechaHasta == other.fechaHasta &&
      tipo == other.tipo;

  @override
  int get hashCode => Object.hash(fechaDesde, fechaHasta, tipo);
}

Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
  for (var i = 0; i < list.length; i += size) {
    yield list.sublist(i, math.min(i + size, list.length));
  }
}

String _isoDate(DateTime d) => d.toIso8601String().split('T')[0];

final listadoRecibosProvider =
    FutureProvider.family<List<ReciboListadoFila>, ListadoRecibosParams>(
        (ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  final tiposOperacion = switch (params.tipo) {
    TipoListadoRecibos.socios => ['COBRANZA_SOCIO'],
    TipoListadoRecibos.profesionales => ['COBRANZA_PROFESIONAL'],
    TipoListadoRecibos.sponsors => ['COBRANZA_SPONSOR'],
    TipoListadoRecibos.todos => [
        'COBRANZA_SOCIO',
        'COBRANZA_PROFESIONAL',
        'COBRANZA_SPONSOR'
      ],
  };

  // 1. Recibos del período (paginado: Supabase devuelve como máximo 1000 filas)
  final ops = <Map<String, dynamic>>[];
  const pageSize = 1000;
  for (var from = 0;; from += pageSize) {
    final page = (await supabase
            .from('operaciones_contables')
            .select('id, tipo_operacion, entidad_id, numero_comprobante, fecha, total')
            .inFilter('tipo_operacion', tiposOperacion)
            .gte('fecha', _isoDate(params.fechaDesde))
            .lte('fecha', _isoDate(params.fechaHasta))
            .order('fecha')
            .order('numero_comprobante')
            .order('id')
            .range(from, from + pageSize - 1) as List)
        .cast<Map<String, dynamic>>();
    ops.addAll(page);
    if (page.length < pageSize) break;
  }
  if (ops.isEmpty) return [];

  // 2. Valores de tesorería de cada recibo (con su concepto y cuenta contable)
  final valoresPorOp = <int, List<Map<String, dynamic>>>{};
  for (final ids in _chunks(ops.map((o) => o['id'] as int).toList(), 200)) {
    final res = (await supabase
            .from('operaciones_detalle_valores_tesoreria')
            .select(
                'operacion_id, valores_tesoreria(importe, conceptos_tesoreria(descripcion, imputacion_contable))')
            .inFilter('operacion_id', ids) as List)
        .cast<Map<String, dynamic>>();
    for (final r in res) {
      final v = r['valores_tesoreria'] as Map<String, dynamic>?;
      if (v == null) continue;
      valoresPorOp.putIfAbsent(r['operacion_id'] as int, () => []).add(v);
    }
  }

  // 3. Nombres de socios, profesionales y sponsors (razón social)
  Future<Map<int, String>> nombres(String tabla, Set<int> ids) async {
    final map = <int, String>{};
    final esSponsor = tabla == 'clientes';
    for (final chunk in _chunks(ids.toList(), 200)) {
      final res = (await supabase
              .from(tabla)
              .select(esSponsor ? 'id, razon_social' : 'id, apellido, nombre')
              .inFilter('id', chunk) as List)
          .cast<Map<String, dynamic>>();
      for (final r in res) {
        if (esSponsor) {
          map[r['id'] as int] = (r['razon_social'] as String?)?.trim() ?? '';
          continue;
        }
        final ap = (r['apellido'] as String?)?.trim() ?? '';
        final no = (r['nombre'] as String?)?.trim() ?? '';
        map[r['id'] as int] = [ap, no].where((s) => s.isNotEmpty).join(', ');
      }
    }
    return map;
  }

  final socios = await nombres(
      'socios',
      ops
          .where((o) => o['tipo_operacion'] == 'COBRANZA_SOCIO')
          .map((o) => o['entidad_id'] as int)
          .toSet());
  final profesionales = await nombres(
      'profesionales',
      ops
          .where((o) => o['tipo_operacion'] == 'COBRANZA_PROFESIONAL')
          .map((o) => o['entidad_id'] as int)
          .toSet());
  final sponsors = await nombres(
      'clientes',
      ops
          .where((o) => o['tipo_operacion'] == 'COBRANZA_SPONSOR')
          .map((o) => o['entidad_id'] as int)
          .toSet());

  // 4. Descripción de las cuentas contables
  final cuentasUsadas = <int>{};
  for (final vs in valoresPorOp.values) {
    for (final v in vs) {
      final c = int.tryParse(
          ((v['conceptos_tesoreria'] as Map<String, dynamic>?)?['imputacion_contable'] ?? '')
              .toString());
      if (c != null) cuentasUsadas.add(c);
    }
  }
  final cuentasDesc = <int, String>{};
  for (final chunk in _chunks(cuentasUsadas.toList(), 200)) {
    final res = (await supabase
            .from('cuentas')
            .select('cuenta, descripcion')
            .inFilter('cuenta', chunk) as List)
        .cast<Map<String, dynamic>>();
    for (final r in res) {
      cuentasDesc[r['cuenta'] as int] = r['descripcion'] as String? ?? '';
    }
  }

  // 5. Armar filas
  final filas = <ReciboListadoFila>[];
  for (final o in ops) {
    final tipoOp = o['tipo_operacion'] as String;
    final entidadId = o['entidad_id'] as int;
    final nombre = (switch (tipoOp) {
          'COBRANZA_SOCIO' => socios[entidadId],
          'COBRANZA_PROFESIONAL' => profesionales[entidadId],
          _ => sponsors[entidadId],
        }) ??
        '(sin datos #$entidadId)';
    final fecha = DateTime.parse(o['fecha'].toString());
    final nro = o['numero_comprobante'] as int?;
    final tipo = switch (tipoOp) {
      'COBRANZA_SOCIO' => 'Socio',
      'COBRANZA_PROFESIONAL' => 'Profesional',
      _ => 'Sponsor',
    };
    final valores = valoresPorOp[o['id'] as int] ?? const [];

    if (valores.isEmpty) {
      // Recibo sin valor registrado: se muestra igual para poder conciliarlo
      filas.add(ReciboListadoFila(
        fecha: fecha,
        numeroRecibo: nro,
        tipo: tipo,
        nombre: nombre,
        cuenta: null,
        cuentaDescripcion: '',
        formaPago: '(sin valor registrado)',
        importe: (o['total'] as num?)?.toDouble() ?? 0,
      ));
      continue;
    }

    for (final v in valores) {
      final concepto = v['conceptos_tesoreria'] as Map<String, dynamic>?;
      final cuenta =
          int.tryParse((concepto?['imputacion_contable'] ?? '').toString());
      filas.add(ReciboListadoFila(
        fecha: fecha,
        numeroRecibo: nro,
        tipo: tipo,
        nombre: nombre,
        cuenta: cuenta,
        cuentaDescripcion: cuenta != null ? (cuentasDesc[cuenta] ?? '') : '',
        formaPago: concepto?['descripcion'] as String? ?? '',
        importe: (v['importe'] as num?)?.toDouble() ?? 0,
      ));
    }
  }
  return filas;
});

// ---------------------------------------------------------------------------
// Página
// ---------------------------------------------------------------------------

class ListadoRecibosPage extends ConsumerStatefulWidget {
  const ListadoRecibosPage({super.key});

  @override
  ConsumerState<ListadoRecibosPage> createState() => _ListadoRecibosPageState();
}

class _ListadoRecibosPageState extends ConsumerState<ListadoRecibosPage> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  late DateTime _fechaDesde;
  late DateTime _fechaHasta;
  TipoListadoRecibos _tipo = TipoListadoRecibos.todos;
  ListadoRecibosParams? _consulta;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaDesde = DateTime(now.year, now.month, 1);
    _fechaHasta = DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickFechaDesde() async {
    final d = await pickDate(context, _fechaDesde);
    if (d != null) setState(() => _fechaDesde = d);
  }

  Future<void> _pickFechaHasta() async {
    final d = await pickDate(context, _fechaHasta);
    if (d != null) setState(() => _fechaHasta = d);
  }

  void _consultar() {
    if (_fechaHasta.isBefore(_fechaDesde)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La fecha hasta no puede ser anterior a la fecha desde')));
      return;
    }
    final params = ListadoRecibosParams(
      fechaDesde: _fechaDesde,
      fechaHasta: _fechaHasta,
      tipo: _tipo,
    );
    // Descarta el resultado cacheado para que "Consultar" siempre lea de la base.
    ref.invalidate(listadoRecibosProvider(params));
    setState(() => _consulta = params);
  }

  String get _tipoTexto => switch (_consulta?.tipo ?? _tipo) {
        TipoListadoRecibos.socios => 'Socios',
        TipoListadoRecibos.profesionales => 'Profesionales',
        TipoListadoRecibos.sponsors => 'Sponsors',
        TipoListadoRecibos.todos => 'Socios, profesionales y sponsors',
      };

  void _descargarExcel(List<ReciboListadoFila> filas) {
    final p = _consulta!;
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Recibos');
    final sheet = excel['Recibos'];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );
    final totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#D9D9D9'),
    );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue(
            'Listado de recibos — Período: ${_dateFormat.format(p.fechaDesde)} al ${_dateFormat.format(p.fechaHasta)}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
        TextCellValue(_tipoTexto);

    const headers = [
      'Fecha',
      'Recibo',
      'Tipo',
      'Apellido y Nombre',
      'Cuenta',
      'Descripción cuenta',
      'Forma de pago',
      'Importe',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (var i = 0; i < filas.length; i++) {
      final f = filas[i];
      final row = i + 4;
      void setCell(int col, CellValue val) => sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          .value = val;

      setCell(0, TextCellValue(_dateFormat.format(f.fecha)));
      if (f.numeroRecibo != null) setCell(1, IntCellValue(f.numeroRecibo!));
      setCell(2, TextCellValue(f.tipo));
      setCell(3, TextCellValue(f.nombre));
      if (f.cuenta != null) setCell(4, IntCellValue(f.cuenta!));
      setCell(5, TextCellValue(f.cuentaDescripcion));
      setCell(6, TextCellValue(f.formaPago));
      setCell(7, DoubleCellValue(f.importe));
    }

    final totRow = filas.length + 4;
    final total = filas.fold(0.0, (s, f) => s + f.importe);
    for (var col = 0; col < headers.length; col++) {
      final cell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: totRow));
      cell.value = col == 0
          ? TextCellValue('TOTAL')
          : col == 7
              ? DoubleCellValue(total)
              : TextCellValue('');
      cell.cellStyle = totalStyle;
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final fileName =
        'listado_recibos_${DateFormat('yyyyMMdd').format(p.fechaDesde)}_${DateFormat('yyyyMMdd').format(p.fechaHasta)}.xlsx';
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    (html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click());
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Archivo Excel descargado')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de Recibos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/listado-recibos'),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: _consulta == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Seleccione el período y presione Consultar',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildResultados(_consulta!),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Listado de Recibos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickFechaDesde,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha Desde',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_dateFormat.format(_fechaDesde)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _pickFechaHasta,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha Hasta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_dateFormat.format(_fechaHasta)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<TipoListadoRecibos>(
                  segments: const [
                    ButtonSegment(
                        value: TipoListadoRecibos.todos, label: Text('Todos')),
                    ButtonSegment(
                        value: TipoListadoRecibos.socios, label: Text('Socios')),
                    ButtonSegment(
                        value: TipoListadoRecibos.profesionales,
                        label: Text('Profesionales')),
                    ButtonSegment(
                        value: TipoListadoRecibos.sponsors,
                        label: Text('Sponsors')),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (s) => setState(() => _tipo = s.first),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _consultar,
                icon: const Icon(Icons.search),
                label: const Text('Consultar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultados(ListadoRecibosParams params) {
    final async = ref.watch(listadoRecibosProvider(params));
    return async.when(
      data: _buildTabla,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $e'),
          ],
        ),
      ),
    );
  }

  // Anchos de columna (la lista usa ListView.builder: puede haber miles de filas)
  static const _wFecha = 100.0;
  static const _wRecibo = 80.0;
  static const _wTipo = 100.0;
  static const _wNombre = 280.0;
  static const _wCuenta = 280.0;
  static const _wForma = 200.0;
  static const _wImporte = 130.0;
  static const _wTotal =
      _wFecha + _wRecibo + _wTipo + _wNombre + _wCuenta + _wForma + _wImporte;

  Widget _celda(String texto, double ancho,
      {bool bold = false, bool derecha = false, Color? color}) {
    return SizedBox(
      width: ancho,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          texto,
          overflow: TextOverflow.ellipsis,
          textAlign: derecha ? TextAlign.right : TextAlign.left,
          style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color),
        ),
      ),
    );
  }

  Widget _fila(List<Widget> celdas, {Color? fondo, double alto = 34}) {
    return Container(
      height: alto,
      color: fondo,
      child: Row(children: celdas),
    );
  }

  Widget _buildTabla(List<ReciboListadoFila> filas) {
    if (filas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay recibos en el período seleccionado',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final total = filas.fold(0.0, (s, f) => s + f.importe);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${filas.length} valor(es) — $_tipoTexto — Total ${_currencyFormat.format(total)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _descargarExcel(filas),
                icon: const Icon(Icons.download),
                label: const Text('Descargar Excel'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _wTotal,
              child: Column(
                children: [
                  _fila([
                    _celda('Fecha', _wFecha, bold: true),
                    _celda('Recibo', _wRecibo, bold: true, derecha: true),
                    _celda('Tipo', _wTipo, bold: true),
                    _celda('Apellido y Nombre', _wNombre, bold: true),
                    _celda('Cuenta contable', _wCuenta, bold: true),
                    _celda('Forma de pago', _wForma, bold: true),
                    _celda('Importe', _wImporte, bold: true, derecha: true),
                  ], fondo: Colors.blue[100], alto: 38),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filas.length,
                      itemExtent: 34,
                      itemBuilder: (context, i) {
                        final f = filas[i];
                        final cuentaTxt = f.cuenta == null
                            ? ''
                            : '${f.cuenta} - ${f.cuentaDescripcion}';
                        return _fila([
                          _celda(_dateFormat.format(f.fecha), _wFecha),
                          _celda(f.numeroRecibo?.toString() ?? '', _wRecibo,
                              derecha: true),
                          _celda(f.tipo, _wTipo),
                          _celda(f.nombre, _wNombre),
                          _celda(cuentaTxt, _wCuenta),
                          _celda(f.formaPago, _wForma,
                              color: f.cuenta == null ? Colors.red[700] : null),
                          _celda(_currencyFormat.format(f.importe), _wImporte,
                              derecha: true),
                        ], fondo: i.isEven ? Colors.white : Colors.grey[50]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
