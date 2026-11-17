import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../cuentas/providers/cuentas_provider.dart';
import '../../../cuentas/models/cuenta_model.dart';
import '../../../../core/utils/date_picker_utils.dart';
import '../../../../core/providers/periodo_trabajo_provider.dart';
import '../widgets/trazabilidad_movimiento_dialog.dart';

/// Modelo para movimiento de cuenta
class MovimientoCuenta {
  final DateTime fecha;
  final int asiento;
  final String detalle;
  final double debe;
  final double haber;

  MovimientoCuenta({
    required this.fecha,
    required this.asiento,
    required this.detalle,
    required this.debe,
    required this.haber,
  });
}

/// Parámetros para el provider
class MayorCuentaParams {
  final int cuenta;
  final DateTime fechaDesde;
  final DateTime fechaHasta;
  final bool acumulado;

  MayorCuentaParams({
    required this.cuenta,
    required this.fechaDesde,
    required this.fechaHasta,
    this.acumulado = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MayorCuentaParams &&
          cuenta == other.cuenta &&
          fechaDesde == other.fechaDesde &&
          fechaHasta == other.fechaHasta &&
          acumulado == other.acumulado;

  @override
  int get hashCode =>
      cuenta.hashCode ^
      fechaDesde.hashCode ^
      fechaHasta.hashCode ^
      acumulado.hashCode;
}

/// Resultado del mayor de cuenta
class MayorCuentaResult {
  final double saldoInicial;
  final List<MovimientoCuenta> movimientos;

  MayorCuentaResult({
    required this.saldoInicial,
    required this.movimientos,
  });

  double get totalDebe => movimientos.fold(0.0, (sum, m) => sum + m.debe);
  double get totalHaber => movimientos.fold(0.0, (sum, m) => sum + m.haber);
  double get saldoFinal => saldoInicial + totalDebe - totalHaber;
}

/// Provider para obtener mayor de una cuenta
final mayorCuentaProvider =
    FutureProvider.family<MayorCuentaResult, MayorCuentaParams>(
        (ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  final result = await supabase.rpc('get_mayor_cuenta', params: {
    'p_cuenta': params.cuenta,
    'p_fecha_desde': params.fechaDesde.toIso8601String().split('T')[0],
    'p_fecha_hasta': params.fechaHasta.toIso8601String().split('T')[0],
    'p_con_apertura': params.acumulado,
  }) as Map<String, dynamic>;

  final saldoInicial = (result['saldo_inicial'] as num?)?.toDouble() ?? 0;
  final rawMovimientos = result['movimientos'] as List? ?? [];

  final movimientos = rawMovimientos.map((row) {
    return MovimientoCuenta(
      fecha: DateTime.parse(row['fecha'] as String),
      asiento: row['asiento'] as int,
      detalle: row['detalle'] as String? ?? '',
      debe: (row['debe'] as num?)?.toDouble() ?? 0,
      haber: (row['haber'] as num?)?.toDouble() ?? 0,
    );
  }).toList();

  return MayorCuentaResult(
    saldoInicial: saldoInicial,
    movimientos: movimientos,
  );
});

class MayorCuentasPage extends ConsumerStatefulWidget {
  const MayorCuentasPage({super.key});

  @override
  ConsumerState<MayorCuentasPage> createState() => _MayorCuentasPageState();
}

class _MayorCuentasPageState extends ConsumerState<MayorCuentasPage> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _cuentaController = TextEditingController();

  late DateTime _fechaDesde;
  late DateTime _fechaHasta;
  bool _acumulado = true;
  bool _trazabilidad = false; // habilita el link asiento -> factura/recibo/cobranza
  bool _hasSearched = false;
  bool _descargandoTodas = false;
  static const int _tamPagina = 100;
  int _pagina = 0;
  int? _cuentaSeleccionada;
  String? _cuentaDescripcion;

  @override
  void initState() {
    super.initState();
    final periodo = ref.read(periodoTrabajoProvider);
    _fechaDesde = periodo.desde;
    _fechaHasta = periodo.hasta;
  }

  @override
  void dispose() {
    _cuentaController.dispose();
    super.dispose();
  }

  Future<void> _selectFechaDesde() async {
    final fecha = await pickDate(context, _fechaDesde);
    if (fecha != null) {
      setState(() => _fechaDesde = fecha);
      ref.read(periodoTrabajoProvider.notifier).setDesde(fecha);
    }
  }

  Future<void> _selectFechaHasta() async {
    final fecha = await pickDate(context, _fechaHasta);
    if (fecha != null) {
      setState(() => _fechaHasta = fecha);
      ref.read(periodoTrabajoProvider.notifier).setHasta(fecha);
    }
  }

  Future<void> _buscarCuenta() async {
    final cuenta = await showDialog<Cuenta>(
      context: context,
      builder: (context) => const _CuentaSearchDialog(),
    );
    if (cuenta != null) {
      setState(() {
        _cuentaSeleccionada = cuenta.cuenta;
        _cuentaDescripcion = cuenta.descripcion;
        _cuentaController.text = '${cuenta.cuenta} - ${cuenta.descripcion}';
      });
    }
  }

  void _buscar() {
    if (_cuentaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar una cuenta')),
      );
      return;
    }
    // Descarta el resultado cacheado para que "Consultar" siempre lea de la base.
    ref.invalidate(mayorCuentaProvider(_params!));
    setState(() {
      _hasSearched = true;
      _pagina = 0;
    });
  }

  MayorCuentaParams? get _params => _cuentaSeleccionada == null
      ? null
      : MayorCuentaParams(
          cuenta: _cuentaSeleccionada!,
          fechaDesde: _fechaDesde,
          fechaHasta: _fechaHasta,
          acumulado: _acumulado,
        );

  void _descargarExcel(MayorCuentaResult mayor) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Mayor');
    final sheet = excel['Mayor'];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );
    final saldoInicialStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#DDEEFF'),
      fontColorHex: ExcelColor.fromHexString('#003399'),
    );
    final totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#D9D9D9'),
    );

    void cell(int col, int row, CellValue val, [CellStyle? style]) {
      final c = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      c.value = val;
      if (style != null) c.cellStyle = style;
    }

    // Fila 0: título
    cell(0, 0, TextCellValue('Mayor de Cuenta'));
    cell(1, 0,
        TextCellValue('$_cuentaSeleccionada — ${_cuentaDescripcion ?? ""}'));
    // Fila 1: período
    cell(0, 1, TextCellValue('Período:'));
    cell(
        1,
        1,
        TextCellValue(
            '${_dateFormat.format(_fechaDesde)} al ${_dateFormat.format(_fechaHasta)}'));
    cell(
        3,
        1,
        TextCellValue(_acumulado
            ? 'Con saldo inicial acumulado'
            : 'Solo período seleccionado'));

    // Fila 3: encabezados de columnas
    const colHeaders = [
      'Fecha',
      'Asiento',
      'Detalle',
      'Debe',
      'Haber',
      'Saldo'
    ];
    for (var i = 0; i < colHeaders.length; i++) {
      cell(i, 3, TextCellValue(colHeaders[i]), headerStyle);
    }

    int row = 4;
    double saldoAcumulado = mayor.saldoInicial;

    // Saldo inicial
    if (_acumulado && mayor.saldoInicial != 0) {
      cell(0, row, TextCellValue(_dateFormat.format(_fechaDesde)),
          saldoInicialStyle);
      cell(1, row, TextCellValue('-'), saldoInicialStyle);
      cell(2, row, TextCellValue('SALDO INICIAL'), saldoInicialStyle);
      cell(3, row, TextCellValue(''), saldoInicialStyle);
      cell(4, row, TextCellValue(''), saldoInicialStyle);
      cell(5, row, DoubleCellValue(mayor.saldoInicial), saldoInicialStyle);
      row++;
    }

    // Movimientos
    for (final mov in mayor.movimientos) {
      saldoAcumulado += mov.debe - mov.haber;
      cell(0, row, TextCellValue(_dateFormat.format(mov.fecha)));
      cell(1, row, IntCellValue(mov.asiento));
      cell(2, row, TextCellValue(mov.detalle));
      cell(
          3, row, mov.debe > 0 ? DoubleCellValue(mov.debe) : TextCellValue(''));
      cell(4, row,
          mov.haber > 0 ? DoubleCellValue(mov.haber) : TextCellValue(''));
      cell(5, row, DoubleCellValue(saldoAcumulado));
      row++;
    }

    // Totales
    cell(0, row, TextCellValue('TOTALES'), totalStyle);
    cell(1, row, TextCellValue(''), totalStyle);
    cell(2, row, TextCellValue(''), totalStyle);
    cell(3, row, DoubleCellValue(mayor.totalDebe), totalStyle);
    cell(4, row, DoubleCellValue(mayor.totalHaber), totalStyle);
    cell(5, row, DoubleCellValue(mayor.saldoFinal), totalStyle);

    final bytes = excel.encode();
    if (bytes == null) return;

    final fileName =
        'mayor_${_cuentaSeleccionada}_${DateFormat('yyyyMMdd').format(_fechaDesde)}_${DateFormat('yyyyMMdd').format(_fechaHasta)}.xlsx';
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    (html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click());
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivo Excel descargado')));
  }

  /// Exporta a Excel el mayor de TODAS las cuentas del período, en un solo archivo:
  /// hoja "Mayor" (cuenta por cuenta, con saldo inicial, movimientos y total) y
  /// hoja "Resumen" (una fila por cuenta).
  Future<void> _descargarTodasLasCuentas() async {
    setState(() => _descargandoTodas = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final raw = await supabase.rpc('get_mayor_todas_cuentas', params: {
        'p_fecha_desde': _fechaDesde.toIso8601String().split('T')[0],
        'p_fecha_hasta': _fechaHasta.toIso8601String().split('T')[0],
        'p_con_apertura': _acumulado,
      });
      final cuentas = (raw as List? ?? const []).cast<Map<String, dynamic>>();
      if (cuentas.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No hay movimientos en el período seleccionado')));
        return;
      }

      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Mayor');
      final sheet = excel['Mayor'];
      final resumen = excel['Resumen'];

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
      );
      final saldoInicialStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#DDEEFF'),
        fontColorHex: ExcelColor.fromHexString('#003399'),
      );
      final totalStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#D9D9D9'),
      );

      void put(Sheet s, int col, int row, CellValue val, [CellStyle? style]) {
        final c =
            s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        c.value = val;
        if (style != null) c.cellStyle = style;
      }

      // ---- Hoja Mayor ----
      put(sheet, 0, 0, TextCellValue('Mayor de todas las cuentas'));
      put(
          sheet,
          2,
          0,
          TextCellValue(
              'Período: ${_dateFormat.format(_fechaDesde)} al ${_dateFormat.format(_fechaHasta)}'
              ' · ${_acumulado ? "Con saldo inicial acumulado" : "Solo período seleccionado"}'));
      const cols = [
        'Cuenta',
        'Descripción',
        'Fecha',
        'Asiento',
        'Detalle',
        'Debe',
        'Haber',
        'Saldo'
      ];
      for (var i = 0; i < cols.length; i++) {
        put(sheet, i, 2, TextCellValue(cols[i]), headerStyle);
      }

      // ---- Hoja Resumen ----
      const colsRes = [
        'Cuenta',
        'Descripción',
        'Saldo inicial',
        'Debe',
        'Haber',
        'Saldo final'
      ];
      for (var i = 0; i < colsRes.length; i++) {
        put(resumen, i, 0, TextCellValue(colsRes[i]), headerStyle);
      }

      double granDebe = 0, granHaber = 0;
      int row = 3;
      int rowRes = 1;
      for (final c in cuentas) {
        final cuenta = c['cuenta'] as int;
        final desc = (c['descripcion'] as String? ?? '').trim();
        final saldoIni = (c['saldo_inicial'] as num?)?.toDouble() ?? 0;
        final movs = (c['movimientos'] as List? ?? const [])
            .cast<Map<String, dynamic>>();

        var saldo = saldoIni;
        double totDebe = 0, totHaber = 0;

        if (_acumulado && saldoIni != 0) {
          put(sheet, 0, row, IntCellValue(cuenta), saldoInicialStyle);
          put(sheet, 1, row, TextCellValue(desc), saldoInicialStyle);
          put(sheet, 2, row, TextCellValue(_dateFormat.format(_fechaDesde)),
              saldoInicialStyle);
          put(sheet, 3, row, TextCellValue('-'), saldoInicialStyle);
          put(sheet, 4, row, TextCellValue('SALDO INICIAL'), saldoInicialStyle);
          put(sheet, 5, row, TextCellValue(''), saldoInicialStyle);
          put(sheet, 6, row, TextCellValue(''), saldoInicialStyle);
          put(sheet, 7, row, DoubleCellValue(saldoIni), saldoInicialStyle);
          row++;
        }

        for (final m in movs) {
          final debe = (m['debe'] as num?)?.toDouble() ?? 0;
          final haber = (m['haber'] as num?)?.toDouble() ?? 0;
          saldo += debe - haber;
          totDebe += debe;
          totHaber += haber;
          put(sheet, 0, row, IntCellValue(cuenta));
          put(sheet, 1, row, TextCellValue(desc));
          put(sheet, 2, row,
              TextCellValue(_dateFormat.format(DateTime.parse(m['fecha'] as String))));
          put(sheet, 3, row, IntCellValue(m['asiento'] as int));
          put(sheet, 4, row, TextCellValue(m['detalle'] as String? ?? ''));
          put(sheet, 5, row, debe > 0 ? DoubleCellValue(debe) : TextCellValue(''));
          put(sheet, 6, row, haber > 0 ? DoubleCellValue(haber) : TextCellValue(''));
          put(sheet, 7, row, DoubleCellValue(saldo));
          row++;
        }

        // Total de la cuenta
        put(sheet, 0, row, IntCellValue(cuenta), totalStyle);
        put(sheet, 1, row, TextCellValue('TOTAL $desc'), totalStyle);
        put(sheet, 2, row, TextCellValue(''), totalStyle);
        put(sheet, 3, row, TextCellValue(''), totalStyle);
        put(sheet, 4, row, TextCellValue(''), totalStyle);
        put(sheet, 5, row, DoubleCellValue(totDebe), totalStyle);
        put(sheet, 6, row, DoubleCellValue(totHaber), totalStyle);
        put(sheet, 7, row, DoubleCellValue(saldo), totalStyle);
        row += 2; // línea en blanco entre cuentas

        put(resumen, 0, rowRes, IntCellValue(cuenta));
        put(resumen, 1, rowRes, TextCellValue(desc));
        put(resumen, 2, rowRes, DoubleCellValue(saldoIni));
        put(resumen, 3, rowRes, DoubleCellValue(totDebe));
        put(resumen, 4, rowRes, DoubleCellValue(totHaber));
        put(resumen, 5, rowRes, DoubleCellValue(saldo));
        rowRes++;

        granDebe += totDebe;
        granHaber += totHaber;
      }

      put(resumen, 0, rowRes, TextCellValue('TOTALES'), totalStyle);
      put(resumen, 1, rowRes, TextCellValue(''), totalStyle);
      put(resumen, 2, rowRes, TextCellValue(''), totalStyle);
      put(resumen, 3, rowRes, DoubleCellValue(granDebe), totalStyle);
      put(resumen, 4, rowRes, DoubleCellValue(granHaber), totalStyle);
      put(resumen, 5, rowRes, TextCellValue(''), totalStyle);

      final bytes = excel.encode();
      if (bytes == null) return;

      final fileName =
          'mayor_todas_las_cuentas_${DateFormat('yyyyMMdd').format(_fechaDesde)}_${DateFormat('yyyyMMdd').format(_fechaHasta)}.xlsx';
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      (html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click());
      html.Url.revokeObjectUrl(url);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Excel descargado: ${cuentas.length} cuentas')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al generar el Excel: $e')));
    } finally {
      if (mounted) setState(() => _descargandoTodas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mayor de Cuentas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/mayor-cuentas'),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Mayor de Cuenta Contable',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Selector de cuenta
                TextField(
                  controller: _cuentaController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Cuenta *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.account_tree),
                    hintText: 'Seleccione una cuenta',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _buscarCuenta,
                      tooltip: 'Buscar cuenta',
                    ),
                  ),
                  onTap: _buscarCuenta,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectFechaDesde,
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
                        onTap: _selectFechaHasta,
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
                        value: _acumulado,
                        onChanged: (value) {
                          setState(() => _acumulado = value ?? true);
                        },
                        title: const Text('Acumulado'),
                        subtitle: Text(
                          _acumulado
                              ? 'Incluye saldo inicial anterior al período'
                              : 'Solo movimientos del período seleccionado',
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        value: _trazabilidad,
                        onChanged: (value) => setState(() => _trazabilidad = value ?? false),
                        title: const Text('Trazabilidad'),
                        subtitle: Text(
                          _trazabilidad
                              ? 'Clic en el asiento: factura, recibo y cobranza'
                              : 'Enlace al asiento desactivado',
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed:
                          _descargandoTodas ? null : _descargarTodasLasCuentas,
                      icon: _descargandoTodas
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.table_view),
                      label: Text(_descargandoTodas
                          ? 'Generando...'
                          : 'Todas las cuentas (Excel)'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _buscar,
                      icon: const Icon(Icons.search),
                      label: const Text('Consultar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Resultados
          Expanded(
            child: !_hasSearched || _params == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Seleccione una cuenta y presione Consultar',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildResultados(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    final mayorAsync = ref.watch(mayorCuentaProvider(_params!));

    return mayorAsync.when(
      data: (mayor) {
        return Column(
          children: [
            // Encabezado con cuenta y saldo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuenta: $_cuentaSeleccionada',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_cuentaDescripcion ?? ''),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${mayor.movimientos.length} movimiento(s)'),
                      Text(
                        'Saldo Final: ${_currencyFormat.format(mayor.saldoFinal)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              mayor.saldoFinal >= 0 ? Colors.blue : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: mayor.movimientos.isEmpty
                        ? null
                        : () => _descargarExcel(mayor),
                    icon: const Icon(Icons.download),
                    label: const Text('Descargar Excel'),
                  ),
                ],
              ),
            ),
            // Tabla de movimientos (paginada; el Excel exporta todo)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(
                          label: Text('Fecha',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Asiento',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Detalle',
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
                    ],
                    rows: _buildRows(mayor),
                  ),
                ),
              ),
            ),
            _buildPaginador(mayor),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
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

  int _totalPaginas(int total) =>
      total == 0 ? 1 : ((total - 1) ~/ _tamPagina) + 1;

  Widget _buildPaginador(MayorCuentaResult mayor) {
    final total = mayor.movimientos.length;
    final paginas = _totalPaginas(total);
    if (paginas <= 1) return const SizedBox.shrink();
    final pag = _pagina.clamp(0, paginas - 1);
    final ini = pag * _tamPagina + 1;
    final fin =
        ((pag + 1) * _tamPagina) > total ? total : (pag + 1) * _tamPagina;
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Primera',
            icon: const Icon(Icons.first_page),
            onPressed: pag > 0 ? () => setState(() => _pagina = 0) : null,
          ),
          IconButton(
            tooltip: 'Anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: pag > 0 ? () => setState(() => _pagina = pag - 1) : null,
          ),
          Text(
              'Movimientos $ini–$fin de $total · Página ${pag + 1} de $paginas'),
          IconButton(
            tooltip: 'Siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: pag < paginas - 1
                ? () => setState(() => _pagina = pag + 1)
                : null,
          ),
          IconButton(
            tooltip: 'Última',
            icon: const Icon(Icons.last_page),
            onPressed: pag < paginas - 1
                ? () => setState(() => _pagina = paginas - 1)
                : null,
          ),
        ],
      ),
    );
  }

  void _verTrazabilidad(MovimientoCuenta mov) {
    mostrarTrazabilidadMovimiento(
      context,
      asiento: mov.asiento,
      fecha: mov.fecha,
      detalle: mov.detalle,
    );
  }

  List<DataRow> _buildRows(MayorCuentaResult mayor) {
    final rows = <DataRow>[];
    double saldoAcumulado = mayor.saldoInicial;
    final total = mayor.movimientos.length;
    final paginas = _totalPaginas(total);
    final pag = _pagina.clamp(0, paginas - 1);
    final ini = pag * _tamPagina;
    final fin = (ini + _tamPagina) > total ? total : ini + _tamPagina;
    // El saldo de la página arranca con lo acumulado de las páginas anteriores.
    for (final m in mayor.movimientos.take(ini)) {
      saldoAcumulado += m.debe - m.haber;
    }

    // Fila de saldo inicial si es acumulado (solo en la primera página)
    if (pag == 0 && _acumulado && mayor.saldoInicial != 0) {
      rows.add(DataRow(
        color: WidgetStateProperty.all(Colors.blue[50]),
        cells: [
          DataCell(Text(_dateFormat.format(_fechaDesde))),
          const DataCell(Text('-')),
          const DataCell(Text('SALDO INICIAL',
              style: TextStyle(fontStyle: FontStyle.italic))),
          const DataCell(Text('')),
          const DataCell(Text('')),
          DataCell(Text(
            _currencyFormat.format(mayor.saldoInicial),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: mayor.saldoInicial >= 0 ? Colors.blue : Colors.red,
            ),
          )),
        ],
      ));
    }

    // Filas de movimientos
    for (final mov in mayor.movimientos.sublist(ini, fin)) {
      saldoAcumulado += mov.debe - mov.haber;
      rows.add(DataRow(
        cells: [
          DataCell(Text(_dateFormat.format(mov.fecha))),
          DataCell(
            Text(
              mov.asiento.toString(),
              style: _trazabilidad
                  ? const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)
                  : null,
            ),
            onTap: _trazabilidad ? () => _verTrazabilidad(mov) : null,
          ),
          DataCell(
            Text(mov.detalle),
            onTap: _trazabilidad ? () => _verTrazabilidad(mov) : null,
          ),
          DataCell(Text(
            mov.debe > 0 ? _currencyFormat.format(mov.debe) : '',
            style: const TextStyle(color: Colors.green),
          )),
          DataCell(Text(
            mov.haber > 0 ? _currencyFormat.format(mov.haber) : '',
            style: const TextStyle(color: Colors.red),
          )),
          DataCell(Text(
            _currencyFormat.format(saldoAcumulado),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: saldoAcumulado >= 0 ? Colors.blue : Colors.red,
            ),
          )),
        ],
      ));
    }

    // Fila de totales (solo en la última página; son los totales de TODO el período)
    if (pag == paginas - 1) {
      rows.add(DataRow(
        color: WidgetStateProperty.all(Colors.grey[200]),
        cells: [
          const DataCell(
              Text('TOTALES', style: TextStyle(fontWeight: FontWeight.bold))),
          const DataCell(Text('')),
          const DataCell(Text('')),
          DataCell(Text(
            _currencyFormat.format(mayor.totalDebe),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.green),
          )),
          DataCell(Text(
            _currencyFormat.format(mayor.totalHaber),
            style:
                const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          )),
          DataCell(Text(
            _currencyFormat.format(mayor.saldoFinal),
            style: const TextStyle(fontWeight: FontWeight.bold),
          )),
        ],
      ));
    }

    return rows;
  }
}

/// Diálogo para buscar y seleccionar una cuenta contable
class _CuentaSearchDialog extends ConsumerStatefulWidget {
  const _CuentaSearchDialog();

  @override
  ConsumerState<_CuentaSearchDialog> createState() =>
      _CuentaSearchDialogState();
}

class _CuentaSearchDialogState extends ConsumerState<_CuentaSearchDialog> {
  final _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cuentasAsync = ref.watch(
      cuentasSearchProvider(CuentasSearchParams(
          searchTerm: _searchTerm.isEmpty ? null : _searchTerm)),
    );

    return AlertDialog(
      title: const Text('Buscar Cuenta'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar por número o descripción',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchTerm = value);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: cuentasAsync.when(
                data: (cuentas) {
                  if (cuentas.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron cuentas'),
                    );
                  }
                  return ListView.builder(
                    itemCount: cuentas.length,
                    itemBuilder: (context, index) {
                      final cuenta = cuentas[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            cuenta.cuenta.toString().substring(0, 2),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(cuenta.descripcion),
                        subtitle: Text('Cuenta: ${cuenta.cuenta}'),
                        onTap: () => Navigator.of(context).pop(cuenta),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
