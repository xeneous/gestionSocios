import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/rechazo_historico.dart';
import '../../providers/historial_rechazos_provider.dart';
import '../../../../../core/presentation/widgets/app_drawer.dart';
import '../../../../../core/utils/web_utils.dart';

class HistorialRechazosPage extends ConsumerStatefulWidget {
  const HistorialRechazosPage({super.key});

  @override
  ConsumerState<HistorialRechazosPage> createState() =>
      _HistorialRechazosPageState();
}

class _HistorialRechazosPageState
    extends ConsumerState<HistorialRechazosPage> {
  int? _tarjetaFiltroId;
  int? _anioFiltro;
  int? _mesFiltro;
  int _currentPage = 1;
  static const int _pageSize = 15;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  int? get _periodoFiltro {
    if (_anioFiltro == null || _mesFiltro == null) return null;
    return _anioFiltro! * 100 + _mesFiltro!;
  }

  @override
  Widget build(BuildContext context) {
    final params = HistorialParams(
      tarjetaId: _tarjetaFiltroId,
      periodo: _periodoFiltro,
    );
    final rechazosAsync = ref.watch(historialRechazosProvider(params));

    final currentYear = DateTime.now().year;
    final anios = List.generate(currentYear - 2023, (i) => 2024 + i);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Rechazos'),
        backgroundColor: Colors.deepOrange,
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
            onPressed: () => abrirEnNuevaPestana('/historial-rechazos'),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/historial-rechazos'),
      body: Column(
        children: [
          // ── Filtros ───────────────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Tarjeta
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Tarjeta:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<int?>(
                        value: _tarjetaFiltroId,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Todas')),
                          DropdownMenuItem(value: 1, child: Text('Visa')),
                          DropdownMenuItem(
                              value: 2, child: Text('Mastercard')),
                        ],
                        onChanged: (v) => setState(() {
                          _tarjetaFiltroId = v;
                          _currentPage = 1;
                        }),
                      ),
                    ],
                  ),
                  // Año
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Año:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<int?>(
                        value: _anioFiltro,
                        hint: const Text('Todos'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Todos')),
                          ...anios.map((a) => DropdownMenuItem(
                              value: a, child: Text(a.toString()))),
                        ],
                        onChanged: (v) => setState(() {
                          _anioFiltro = v;
                          if (v == null) _mesFiltro = null;
                          _currentPage = 1;
                        }),
                      ),
                    ],
                  ),
                  // Mes
                  if (_anioFiltro != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Mes:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        DropdownButton<int?>(
                          value: _mesFiltro,
                          hint: const Text('Todos'),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('Todos')),
                            ...List.generate(
                              12,
                              (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(_meses[i])),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _mesFiltro = v;
                            _currentPage = 1;
                          }),
                        ),
                      ],
                    ),
                  // Limpiar período
                  if (_anioFiltro != null)
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Limpiar período'),
                      onPressed: () => setState(() {
                        _anioFiltro = null;
                        _mesFiltro = null;
                        _currentPage = 1;
                      }),
                    ),
                  // Refrescar
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar',
                    onPressed: () {
                      setState(() => _currentPage = 1);
                      ref.invalidate(historialRechazosProvider(params));
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Contenido ─────────────────────────────────────────────────────
          Expanded(
            child: rechazosAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Error: $e'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.invalidate(historialRechazosProvider(params)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (rechazos) {
                if (rechazos.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No hay rechazos registrados para los filtros seleccionados'),
                      ],
                    ),
                  );
                }

                final totalPages =
                    (rechazos.length / _pageSize).ceil().clamp(1, 9999);
                final page = _currentPage.clamp(1, totalPages);
                final offset = (page - 1) * _pageSize;
                final pagina = rechazos.skip(offset).take(_pageSize).toList();

                return Column(
                  children: [
                    // Contador
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '${rechazos.length} rechazo(s)',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    // Tabla
                    Expanded(child: _buildTabla(pagina)),
                    // Paginación
                    if (rechazos.length > _pageSize)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: page > 1
                                  ? () => setState(
                                      () => _currentPage = page - 1)
                                  : null,
                            ),
                            Text('Página $page de $totalPages',
                                style: const TextStyle(fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: page < totalPages
                                  ? () => setState(
                                      () => _currentPage = page + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabla(List<RechazoHistorico> rechazos) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor:
              WidgetStateProperty.all(Colors.deepOrange.shade50),
          columns: const [
            DataColumn(label: Text('Período')),
            DataColumn(label: Text('Tarjeta')),
            DataColumn(label: Text('Socio')),
            DataColumn(label: Text('Importe'), numeric: true),
            DataColumn(label: Text('N° Tarjeta')),
            DataColumn(label: Text('Motivo')),
            DataColumn(label: Text('Fecha Rechazo')),
          ],
          rows: rechazos.map((r) => _buildRow(r)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(RechazoHistorico r) {
    final anio = r.periodo ~/ 100;
    final mes = r.periodo % 100;
    final periodoStr =
        '${mes.toString().padLeft(2, '0')}/$anio';

    return DataRow(cells: [
      DataCell(Text(periodoStr)),
      DataCell(_buildTarjetaChip(r.nombreTarjeta)),
      DataCell(Text(r.nombreCompleto)),
      DataCell(Text(_currencyFormat.format(r.importe))),
      DataCell(Text(r.numeroTarjetaEnmascarado)),
      DataCell(
        Tooltip(
          message: r.motivo ?? '',
          child: Text(
            r.motivo != null && r.motivo!.length > 30
                ? '${r.motivo!.substring(0, 30)}...'
                : r.motivo ?? '-',
          ),
        ),
      ),
      DataCell(Text(r.fechaRechazo != null
          ? _dateFormat.format(r.fechaRechazo!)
          : '-')),
    ]);
  }

  Widget _buildTarjetaChip(String nombre) {
    final isVisa = nombre.toLowerCase().contains('visa');
    return Chip(
      label: Text(
        nombre,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: isVisa ? Colors.blue : Colors.orange,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
