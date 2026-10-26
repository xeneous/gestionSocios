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

class FilaSumasSaldos {
  final int cuenta;
  final String descripcion;
  final double inicio;
  final double debe;
  final double haber;
  final double saldo;

  FilaSumasSaldos({
    required this.cuenta,
    required this.descripcion,
    required this.inicio,
    required this.debe,
    required this.haber,
    required this.saldo,
  });

  factory FilaSumasSaldos.fromMap(Map<String, dynamic> m) => FilaSumasSaldos(
        cuenta: m['cuenta'] as int,
        descripcion: m['descripcion'] as String? ?? '',
        inicio: (m['inicio'] as num?)?.toDouble() ?? 0,
        debe: (m['debe'] as num?)?.toDouble() ?? 0,
        haber: (m['haber'] as num?)?.toDouble() ?? 0,
        saldo: (m['saldo'] as num?)?.toDouble() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Params + Provider
// ---------------------------------------------------------------------------

class SumasSaldosParams {
  final DateTime fechaDesde;
  final DateTime fechaHasta;
  final bool conApertura;

  SumasSaldosParams({
    required this.fechaDesde,
    required this.fechaHasta,
    required this.conApertura,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SumasSaldosParams &&
          fechaDesde == other.fechaDesde &&
          fechaHasta == other.fechaHasta &&
          conApertura == other.conApertura;

  @override
  int get hashCode =>
      fechaDesde.hashCode ^ fechaHasta.hashCode ^ conApertura.hashCode;
}

final sumasSaldosProvider =
    FutureProvider.family<List<FilaSumasSaldos>, SumasSaldosParams>(
        (ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  final desde = params.fechaDesde.toIso8601String().split('T')[0];
  final hasta = params.fechaHasta.toIso8601String().split('T')[0];

  final response = await supabase.rpc('get_sumas_y_saldos', params: {
    'p_fecha_desde': desde,
    'p_fecha_hasta': hasta,
    'p_con_apertura': params.conApertura,
  });

  return (response as List)
      .map((e) => FilaSumasSaldos.fromMap(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Página
// ---------------------------------------------------------------------------

class SumasSaldosPage extends ConsumerStatefulWidget {
  const SumasSaldosPage({super.key});

  @override
  ConsumerState<SumasSaldosPage> createState() => _SumasSaldosPageState();
}

class _SumasSaldosPageState extends ConsumerState<SumasSaldosPage> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  late DateTime _fechaDesde;
  late DateTime _fechaHasta;
  bool _conApertura = true;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaDesde = DateTime(now.year, 1, 1);
    _fechaHasta = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _pickFechaDesde() async {
    final d = await pickDate(context, _fechaDesde);
    if (d != null) setState(() => _fechaDesde = d);
  }

  Future<void> _pickFechaHasta() async {
    final d = await pickDate(context, _fechaHasta);
    if (d != null) setState(() => _fechaHasta = d);
  }

  void _consultar() => setState(() => _hasSearched = true);

  SumasSaldosParams get _params => SumasSaldosParams(
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        conApertura: _conApertura,
      );

  void _descargarExcel(List<FilaSumasSaldos> filas) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Sumas y Saldos');
    final sheet = excel['Sumas y Saldos'];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );
    final totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#D9D9D9'),
    );

    // Fila de título
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue(
            'Sumas y Saldos — Período: ${_dateFormat.format(_fechaDesde)} al ${_dateFormat.format(_fechaHasta)}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
        TextCellValue(
            _conApertura ? 'Con saldo de apertura' : 'Sin saldo de apertura');

    // Encabezados
    final headers = _conApertura
        ? ['Cuenta', 'Descripción', 'Inicio', 'Debe', 'Haber', 'Saldo']
        : ['Cuenta', 'Descripción', 'Debe', 'Haber', 'Saldo'];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Datos
    for (var i = 0; i < filas.length; i++) {
      final f = filas[i];
      final row = i + 4;
      void setCell(int col, CellValue val) =>
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value = val;

      if (_conApertura) {
        setCell(0, IntCellValue(f.cuenta));
        setCell(1, TextCellValue(f.descripcion));
        setCell(2, DoubleCellValue(f.inicio));
        setCell(3, DoubleCellValue(f.debe));
        setCell(4, DoubleCellValue(f.haber));
        setCell(5, DoubleCellValue(f.saldo));
      } else {
        setCell(0, IntCellValue(f.cuenta));
        setCell(1, TextCellValue(f.descripcion));
        setCell(2, DoubleCellValue(f.debe));
        setCell(3, DoubleCellValue(f.haber));
        setCell(4, DoubleCellValue(f.saldo));
      }
    }

    // Fila de totales
    final totRow = filas.length + 4;
    final totInicio = filas.fold(0.0, (s, f) => s + f.inicio);
    final totDebe = filas.fold(0.0, (s, f) => s + f.debe);
    final totHaber = filas.fold(0.0, (s, f) => s + f.haber);
    final totSaldo = filas.fold(0.0, (s, f) => s + f.saldo);

    void setTotal(int col, CellValue val) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: totRow));
      cell.value = val;
      cell.cellStyle = totalStyle;
    }

    if (_conApertura) {
      setTotal(0, TextCellValue('TOTALES'));
      setTotal(1, TextCellValue(''));
      setTotal(2, DoubleCellValue(totInicio));
      setTotal(3, DoubleCellValue(totDebe));
      setTotal(4, DoubleCellValue(totHaber));
      setTotal(5, DoubleCellValue(totSaldo));
    } else {
      setTotal(0, TextCellValue('TOTALES'));
      setTotal(1, TextCellValue(''));
      setTotal(2, DoubleCellValue(totDebe));
      setTotal(3, DoubleCellValue(totHaber));
      setTotal(4, DoubleCellValue(totSaldo));
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final fileName =
        'sumas_saldos_${DateFormat('yyyyMMdd').format(_fechaDesde)}_${DateFormat('yyyyMMdd').format(_fechaHasta)}.xlsx';
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
        title: const Text('Sumas y Saldos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/sumas-saldos'),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: !_hasSearched
                ? const _EmptyState()
                : _buildResultados(),
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
              Icon(Icons.balance, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Sumas y Saldos Contable',
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
                child: CheckboxListTile(
                  value: _conApertura,
                  onChanged: (v) => setState(() => _conApertura = v ?? true),
                  title: const Text('Incluir saldo de apertura'),
                  subtitle: Text(
                    _conApertura
                        ? 'Columna Inicio: saldo acumulado antes del período'
                        : 'Solo movimientos dentro del período',
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
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

  Widget _buildResultados() {
    final async = ref.watch(sumasSaldosProvider(_params));
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

  Widget _buildTabla(List<FilaSumasSaldos> filas) {
    if (filas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay movimientos en el período seleccionado',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final totInicio = filas.fold(0.0, (s, f) => s + f.inicio);
    final totDebe = filas.fold(0.0, (s, f) => s + f.debe);
    final totHaber = filas.fold(0.0, (s, f) => s + f.haber);
    final totSaldo = filas.fold(0.0, (s, f) => s + f.saldo);

    return Column(
      children: [
        // Encabezado de resultados
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${filas.length} cuenta(s) con movimiento',
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
        // Tabla
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 20,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 36,
                headingRowColor:
                    WidgetStateProperty.all(Colors.blue[100]),
                columns: [
                  const DataColumn(
                    label: Text('Cuenta',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                  ),
                  const DataColumn(
                    label: Text('Descripción',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (_conApertura)
                    const DataColumn(
                      label: Text('Inicio',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true,
                    ),
                  const DataColumn(
                    label: Text('Debe',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                  ),
                  const DataColumn(
                    label: Text('Haber',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                  ),
                  const DataColumn(
                    label: Text('Saldo',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                  ),
                ],
                rows: [
                  // Filas de datos
                  ...filas.map((f) => DataRow(
                        cells: [
                          DataCell(Text(f.cuenta.toString())),
                          DataCell(Text(f.descripcion)),
                          if (_conApertura)
                            DataCell(Text(
                              _currencyFormat.format(f.inicio),
                              style: TextStyle(
                                color: f.inicio < 0
                                    ? Colors.red[700]
                                    : null,
                              ),
                            )),
                          DataCell(Text(
                            f.debe > 0
                                ? _currencyFormat.format(f.debe)
                                : '',
                            style: const TextStyle(color: Colors.green),
                          )),
                          DataCell(Text(
                            f.haber > 0
                                ? _currencyFormat.format(f.haber)
                                : '',
                            style: const TextStyle(color: Colors.red),
                          )),
                          DataCell(Text(
                            _currencyFormat.format(f.saldo),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: f.saldo < 0
                                  ? Colors.red[700]
                                  : Colors.blue[700],
                            ),
                          )),
                        ],
                      )),
                  // Fila de totales
                  DataRow(
                    color: WidgetStateProperty.all(Colors.grey[200]),
                    cells: [
                      const DataCell(SizedBox.shrink()),
                      const DataCell(Text('TOTALES',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                      if (_conApertura)
                        DataCell(Text(
                          _currencyFormat.format(totInicio),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )),
                      DataCell(Text(
                        _currencyFormat.format(totDebe),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green),
                      )),
                      DataCell(Text(
                        _currencyFormat.format(totHaber),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red),
                      )),
                      DataCell(Text(
                        _currencyFormat.format(totSaldo),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                    ],
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.balance, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Seleccione el período y presione Consultar',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
