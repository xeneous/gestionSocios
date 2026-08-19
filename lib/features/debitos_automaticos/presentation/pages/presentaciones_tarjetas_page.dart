import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import '../../../../core/utils/date_picker_utils.dart';
import '../../../../core/utils/web_utils.dart';
import '../../models/presentacion_tarjeta.dart';
import '../../providers/presentaciones_tarjetas_provider.dart';
import '../../../../../core/presentation/widgets/app_drawer.dart';

class PresentacionesTarjetasPage extends ConsumerStatefulWidget {
  const PresentacionesTarjetasPage({super.key});

  @override
  ConsumerState<PresentacionesTarjetasPage> createState() =>
      _PresentacionesTarjetasPageState();
}

class _PresentacionesTarjetasPageState
    extends ConsumerState<PresentacionesTarjetasPage> {
  int? _tarjetaFiltroId; // null = todas
  int _currentPage = 1;
  static const int _pageSize = 12;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

  final _busquedaTarjetaController = TextEditingController();
  String? _numeroTarjetaBuscado;
  DateTime? _periodoDesde;
  DateTime? _periodoHasta;

  @override
  void dispose() {
    _busquedaTarjetaController.dispose();
    super.dispose();
  }

  void _buscarPorTarjeta() {
    final valor = _busquedaTarjetaController.text.trim();
    setState(() => _numeroTarjetaBuscado = valor.isEmpty ? null : valor);
  }

  void _limpiarBusqueda() {
    setState(() {
      _busquedaTarjetaController.clear();
      _numeroTarjetaBuscado = null;
      _periodoDesde = null;
      _periodoHasta = null;
    });
  }

  int? get _periodoDesdeInt => _periodoDesde == null
      ? null
      : _periodoDesde!.year * 100 + _periodoDesde!.month;

  int? get _periodoHastaInt => _periodoHasta == null
      ? null
      : _periodoHasta!.year * 100 + _periodoHasta!.month;

  Future<void> _seleccionarPeriodoDesde() async {
    final fecha = await pickDate(context, _periodoDesde ?? DateTime.now());
    if (fecha != null) setState(() => _periodoDesde = fecha);
  }

  Future<void> _seleccionarPeriodoHasta() async {
    final fecha = await pickDate(context, _periodoHasta ?? DateTime.now());
    if (fecha != null) setState(() => _periodoHasta = fecha);
  }

  @override
  Widget build(BuildContext context) {
    // Siempre cargamos todas las presentaciones; el filtro es client-side
    final presentacionesAsync = ref.watch(presentacionesTarjetasProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentaciones Débito Automático'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Inicio',
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Abrir en nueva pestaña',
            onPressed: () => abrirEnNuevaPestana('/presentaciones-tarjetas'),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/presentaciones-tarjetas'),
      body: Column(
        children: [
          // ── Buscador por N° de tarjeta ───────────────────────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _busquedaTarjetaController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por N° de tarjeta',
                        hintText: 'Ej: 4937020001788817',
                        prefixIcon: Icon(Icons.credit_card),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _buscarPorTarjeta(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _buscarPorTarjeta,
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar'),
                  ),
                  if (_numeroTarjetaBuscado != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _limpiarBusqueda,
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: _numeroTarjetaBuscado != null
                ? _buildResultadoBusquedaTarjeta(_numeroTarjetaBuscado!)
                : _buildListaPresentaciones(presentacionesAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildResultadoBusquedaTarjeta(String numeroTarjeta) {
    final resultadoAsync = ref.watch(buscarPorTarjetaProvider(numeroTarjeta));
    final mesFmt = DateFormat('MM/yyyy');

    return resultadoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (todosLosMovimientos) {
        if (todosLosMovimientos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.credit_card_off, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No se encontraron movimientos para esa tarjeta'),
              ],
            ),
          );
        }

        final desde = _periodoDesdeInt;
        final hasta = _periodoHastaInt;
        final movimientos = todosLosMovimientos.where((m) {
          if (desde != null && m.periodo < desde) return false;
          if (hasta != null && m.periodo > hasta) return false;
          return true;
        }).toList();

        final socios = movimientos.map((m) => m.socioId).toSet().length;
        final totalCobrado = movimientos
            .where((m) => !m.rechazado)
            .fold<double>(0.0, (sum, m) => sum + m.importe);
        final totalRechazado = movimientos
            .where((m) => m.rechazado)
            .fold<double>(0.0, (sum, m) => sum + m.importe);

        return Column(
          children: [
            // ── Filtro de período (desde / hasta) ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Text('Período:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _seleccionarPeriodoDesde,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_periodoDesde != null
                          ? 'Desde ${mesFmt.format(_periodoDesde!)}'
                          : 'Desde...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _seleccionarPeriodoHasta,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_periodoHasta != null
                          ? 'Hasta ${mesFmt.format(_periodoHasta!)}'
                          : 'Hasta...'),
                    ),
                  ),
                  if (_periodoDesde != null || _periodoHasta != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _periodoDesde = null;
                        _periodoHasta = null;
                      }),
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Limpiar período'),
                    ),
                  ],
                ],
              ),
            ),
            if (movimientos.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                      'No hay movimientos en el rango de período seleccionado'),
                ),
              )
            else ...[
              Container(
                width: double.infinity,
                color: Colors.purple.shade50,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          Text('$socios socio(s) con esta tarjeta',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              'Cobrado: ${_currencyFormat.format(totalCobrado)}',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              'Rechazado: ${_currencyFormat.format(totalRechazado)}',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _exportarExcelBusqueda(numeroTarjeta, movimientos),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Exportar Excel'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor:
                          WidgetStateProperty.all(Colors.purple.shade50),
                      columns: const [
                        DataColumn(label: Text('Socio ID')),
                        DataColumn(label: Text('Apellido y Nombre')),
                        DataColumn(label: Text('Período')),
                        DataColumn(label: Text('Importe'), numeric: true),
                        DataColumn(label: Text('Estado')),
                      ],
                      rows: movimientos.map((m) {
                        final anio = m.periodo ~/ 100;
                        final mes = m.periodo % 100;
                        final periodoStr =
                            '${mes.toString().padLeft(2, '0')}/$anio';
                        return DataRow(cells: [
                          DataCell(Text(m.socioId.toString())),
                          DataCell(Text(m.nombreCompleto)),
                          DataCell(Text(periodoStr)),
                          DataCell(Text(_currencyFormat.format(m.importe))),
                          DataCell(Chip(
                            label: Text(
                              m.rechazado ? 'Rechazado' : 'Cobrado',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white),
                            ),
                            backgroundColor:
                                m.rechazado ? Colors.red : Colors.green,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _exportarExcelBusqueda(
      String numeroTarjeta, List<DetalleTarjetaBusqueda> movimientos) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Movimientos'];
    excel.setDefaultSheet('Movimientos');

    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#7B1FA2'),
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
    );

    final headers = [
      'Socio ID', 'Apellido y Nombre', 'Período', 'Importe', 'Estado',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = xl.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (var i = 0; i < movimientos.length; i++) {
      final m = movimientos[i];
      final anio = m.periodo ~/ 100;
      final mes = m.periodo % 100;
      final periodoStr = '${mes.toString().padLeft(2, '0')}/$anio';
      final row = i + 1;

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = xl.IntCellValue(m.socioId);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = xl.TextCellValue(m.nombreCompleto);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = xl.TextCellValue(periodoStr);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = xl.DoubleCellValue(m.importe);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = xl.TextCellValue(m.rechazado ? 'Rechazado' : 'Cobrado');
    }

    sheet.setColumnWidth(0, 10);
    sheet.setColumnWidth(1, 28);
    sheet.setColumnWidth(2, 10);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 12);

    final bytes = excel.encode();
    if (bytes == null) return;

    final nombreArchivo = 'Movimientos_Tarjeta_$numeroTarjeta.xlsx';

    if (kIsWeb) {
      final blob = html.Blob(
        [bytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', nombreArchivo)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final directory = await getDownloadsDirectory();
      if (directory == null) return;
      final file = File('${directory.path}/$nombreArchivo');
      await file.writeAsBytes(bytes);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel generado: $nombreArchivo'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildListaPresentaciones(
      AsyncValue<List<PresentacionTarjeta>> presentacionesAsync) {
    return presentacionesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error: $e'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.invalidate(presentacionesTarjetasProvider(null)),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (todas) {
          // Derivar tarjetas únicas de los datos cargados
          final tarjetasMap = <int, String>{};
          for (final p in todas) {
            tarjetasMap[p.tarjetaId] = p.nombreTarjeta;
          }

          // Filtrar client-side
          final filtradas = _tarjetaFiltroId == null
              ? todas
              : todas.where((p) => p.tarjetaId == _tarjetaFiltroId).toList();

          final totalPages = (filtradas.length / _pageSize).ceil().clamp(1, 9999);
          final currentPage = _currentPage.clamp(1, totalPages);
          final offset = (currentPage - 1) * _pageSize;
          final presentaciones =
              filtradas.skip(offset).take(_pageSize).toList();

          return Column(
            children: [
              // ── Filtro ────────────────────────────────────────────────
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Text('Tarjeta:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      DropdownButton<int?>(
                        value: _tarjetaFiltroId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todas'),
                          ),
                          ...tarjetasMap.entries.map((e) =>
                              DropdownMenuItem<int?>(
                                value: e.key,
                                child: Text(e.value),
                              )),
                        ],
                        onChanged: (value) => setState(() {
                          _tarjetaFiltroId = value;
                          _currentPage = 1;
                        }),
                      ),
                      const Spacer(),
                      Text(
                        '${filtradas.length} presentaciones',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Actualizar',
                        onPressed: () {
                          setState(() => _currentPage = 1);
                          ref.invalidate(presentacionesTarjetasProvider(null));
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tabla ─────────────────────────────────────────────────
              Expanded(
                child: filtradas.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No hay presentaciones registradas'),
                          ],
                        ),
                      )
                    : _buildTabla(presentaciones),
              ),

              // ── Paginación ────────────────────────────────────────────
              if (filtradas.length > _pageSize)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: currentPage > 1
                            ? () => setState(() => _currentPage = currentPage - 1)
                            : null,
                      ),
                      Text(
                        'Página $currentPage de $totalPages',
                        style: const TextStyle(fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: currentPage < totalPages
                            ? () => setState(() => _currentPage = currentPage + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
  }

  Widget _buildTabla(List<PresentacionTarjeta> presentaciones) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(Colors.purple.shade50),
          columns: const [
            DataColumn(label: Text('Fecha\nPresentación')),
            DataColumn(label: Text('Tarjeta')),
            DataColumn(label: Text('Total'), numeric: true),
            DataColumn(label: Text('Acreditación')),
            DataColumn(label: Text('Comisión'), numeric: true),
            DataColumn(label: Text('Neto'), numeric: true),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: presentaciones.map((p) => _buildRow(p)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(PresentacionTarjeta p) {
    return DataRow(cells: [
      DataCell(Text(_dateFormat.format(p.fechaPresentacion))),
      DataCell(Text(p.nombreTarjeta)),
      DataCell(Text(_currencyFormat.format(p.total))),
      DataCell(Text(p.fechaAcreditacion != null
          ? _dateFormat.format(p.fechaAcreditacion!)
          : '-')),
      DataCell(Text(
          p.comision != null ? _currencyFormat.format(p.comision!) : '-')),
      DataCell(
          Text(p.neto != null ? _currencyFormat.format(p.neto!) : '-')),
      DataCell(_buildEstadoChip(p.procesado)),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: p.procesado ? Colors.grey : Colors.purple,
            ),
            tooltip: 'Registrar acreditación',
            onPressed: () => _mostrarDialogAcreditacion(p),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.blue),
            tooltip: 'Ver detalle',
            onPressed: () => context.go(
              '/presentaciones-tarjetas/detalle',
              extra: p,
            ),
          ),
        ],
      )),
    ]);
  }

  Widget _buildEstadoChip(bool procesado) {
    return Chip(
      label: Text(
        procesado ? 'Procesado' : 'Pendiente',
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: procesado ? Colors.green : Colors.orange,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _mostrarDialogAcreditacion(PresentacionTarjeta presentacion) {
    showDialog(
      context: context,
      builder: (ctx) => _DialogAcreditacion(
        presentacion: presentacion,
        onGuardado: () =>
            ref.invalidate(presentacionesTarjetasProvider(null)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Diálogo de acreditación
// ════════════════════════════════════════════════════════════════════════════

class _DialogAcreditacion extends ConsumerStatefulWidget {
  final PresentacionTarjeta presentacion;
  final VoidCallback onGuardado;

  const _DialogAcreditacion({
    required this.presentacion,
    required this.onGuardado,
  });

  @override
  ConsumerState<_DialogAcreditacion> createState() =>
      _DialogAcreditacionState();
}

class _DialogAcreditacionState extends ConsumerState<_DialogAcreditacion> {
  final _formKey = GlobalKey<FormState>();
  final _comisionController = TextEditingController();
  DateTime? _fechaAcreditacion;
  bool _guardando = false;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    if (widget.presentacion.fechaAcreditacion != null) {
      _fechaAcreditacion = widget.presentacion.fechaAcreditacion;
    }
    if (widget.presentacion.comision != null) {
      _comisionController.text =
          widget.presentacion.comision!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _comisionController.dispose();
    super.dispose();
  }

  double get _comision =>
      double.tryParse(_comisionController.text.replaceAll(',', '.')) ?? 0.0;

  double get _neto => widget.presentacion.total - _comision;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Acreditación – ${widget.presentacion.nombreTarjeta}',
        style: const TextStyle(fontSize: 16),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Presentación: ${_dateFormat.format(widget.presentacion.fechaPresentacion)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Total: ${_currencyFormat.format(widget.presentacion.total)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _seleccionarFecha,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de acreditación *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _fechaAcreditacion != null
                        ? _dateFormat.format(_fechaAcreditacion!)
                        : 'Seleccionar...',
                    style: TextStyle(
                      color: _fechaAcreditacion != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _comisionController,
                decoration: const InputDecoration(
                  labelText: 'Comisión *',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*[.,]?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingrese la comisión';
                  final val =
                      double.tryParse(v.replaceAll(',', '.')) ?? -1;
                  if (val < 0) return 'Valor inválido';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Neto:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      _currencyFormat.format(_neto),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _neto >= 0
                            ? Colors.blue.shade700
                            : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Guardar',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaAcreditacion ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('es', 'AR'),
    );
    if (picked != null) {
      setState(() => _fechaAcreditacion = picked);
    }
  }

  Future<void> _guardar() async {
    if (_fechaAcreditacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Seleccione la fecha de acreditación'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final service = ref.read(historialPresentacionesServiceProvider);
      await service.actualizarAcreditacion(
        id: widget.presentacion.id,
        fechaAcreditacion: _fechaAcreditacion!,
        comision: _comision,
        neto: _neto,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onGuardado();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acreditación registrada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
