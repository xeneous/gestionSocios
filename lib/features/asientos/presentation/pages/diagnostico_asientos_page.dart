import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../../core/utils/date_picker_utils.dart';

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

class AsientoDesbalanceado {
  final int asiento;
  final int anioMes;
  final DateTime fecha;
  final int tipoAsiento;
  final String detalle;
  final double totalDebe;
  final double totalHaber;
  final double diferencia;

  AsientoDesbalanceado({
    required this.asiento,
    required this.anioMes,
    required this.fecha,
    required this.tipoAsiento,
    required this.detalle,
    required this.totalDebe,
    required this.totalHaber,
    required this.diferencia,
  });

  factory AsientoDesbalanceado.fromMap(Map<String, dynamic> m) =>
      AsientoDesbalanceado(
        asiento: m['asiento'] as int,
        anioMes: m['anio_mes'] as int,
        fecha: DateTime.parse(m['fecha'] as String),
        tipoAsiento: m['tipo_asiento'] as int,
        detalle: m['detalle'] as String? ?? '',
        totalDebe: (m['total_debe'] as num?)?.toDouble() ?? 0,
        totalHaber: (m['total_haber'] as num?)?.toDouble() ?? 0,
        diferencia: (m['diferencia'] as num?)?.toDouble() ?? 0,
      );

  static String nombreTipo(int tipo) => switch (tipo) {
        0 => 'Diario',
        1 => 'Ingreso',
        2 => 'Egreso',
        3 => 'Compras',
        4 => 'Ventas',
        _ => 'Tipo $tipo',
      };
}

class CuentaInexistente {
  final int cuentaId;
  final int cantidadUsos;
  final int primerAsiento;
  final DateTime? ultimaFecha;

  CuentaInexistente({
    required this.cuentaId,
    required this.cantidadUsos,
    required this.primerAsiento,
    this.ultimaFecha,
  });

  factory CuentaInexistente.fromMap(Map<String, dynamic> m) =>
      CuentaInexistente(
        cuentaId: m['cuenta_id'] as int,
        cantidadUsos: m['cantidad_usos'] as int,
        primerAsiento: m['primer_asiento'] as int,
        ultimaFecha: m['ultima_fecha'] != null
            ? DateTime.parse(m['ultima_fecha'] as String)
            : null,
      );
}

// ---------------------------------------------------------------------------
// Params + Providers
// ---------------------------------------------------------------------------

class DiagnosticoParams {
  final DateTime fechaDesde;
  final DateTime fechaHasta;

  const DiagnosticoParams({required this.fechaDesde, required this.fechaHasta});

  @override
  bool operator ==(Object other) =>
      other is DiagnosticoParams &&
      fechaDesde == other.fechaDesde &&
      fechaHasta == other.fechaHasta;

  @override
  int get hashCode => fechaDesde.hashCode ^ fechaHasta.hashCode;
}

final asientosDesbalanceadosProvider = FutureProvider.family<
    List<AsientoDesbalanceado>, DiagnosticoParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  final desde = params.fechaDesde.toIso8601String().split('T')[0];
  final hasta = params.fechaHasta.toIso8601String().split('T')[0];

  final response = await supabase.rpc('get_asientos_desbalanceados', params: {
    'p_fecha_desde': desde,
    'p_fecha_hasta': hasta,
  });

  return (response as List)
      .map((e) => AsientoDesbalanceado.fromMap(e as Map<String, dynamic>))
      .toList();
});

final cuentasInexistentesProvider = FutureProvider.family<
    List<CuentaInexistente>, DiagnosticoParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  final desde = params.fechaDesde.toIso8601String().split('T')[0];
  final hasta = params.fechaHasta.toIso8601String().split('T')[0];

  final response =
      await supabase.rpc('get_cuentas_inexistentes_en_asientos', params: {
    'p_fecha_desde': desde,
    'p_fecha_hasta': hasta,
  });

  return (response as List)
      .map((e) => CuentaInexistente.fromMap(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Página
// ---------------------------------------------------------------------------

class DiagnosticoAsientosPage extends ConsumerStatefulWidget {
  const DiagnosticoAsientosPage({super.key});

  @override
  ConsumerState<DiagnosticoAsientosPage> createState() =>
      _DiagnosticoAsientosPageState();
}

class _DiagnosticoAsientosPageState
    extends ConsumerState<DiagnosticoAsientosPage>
    with SingleTickerProviderStateMixin {
  final _currency = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  late DateTime _fechaDesde;
  late DateTime _fechaHasta;
  bool _hasSearched = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaDesde = DateTime(now.year, 1, 1);
    _fechaHasta = DateTime(now.year, now.month + 1, 0);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DiagnosticoParams get _params =>
      DiagnosticoParams(fechaDesde: _fechaDesde, fechaHasta: _fechaHasta);

  void _consultar() => setState(() => _hasSearched = true);

  Future<void> _pickDesde() async {
    final d = await pickDate(context, _fechaDesde);
    if (d != null) setState(() => _fechaDesde = d);
  }

  Future<void> _pickHasta() async {
    final d = await pickDate(context, _fechaHasta);
    if (d != null) setState(() => _fechaHasta = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de Asientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
        bottom: _hasSearched
            ? TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.warning_amber_rounded),
                    child: _buildTabLabel('Desbalanceados'),
                  ),
                  Tab(
                    icon: const Icon(Icons.search_off),
                    child: _buildTabLabel('Cuentas inexistentes'),
                  ),
                ],
              )
            : null,
      ),
      drawer: AppDrawer(currentRoute: '/diagnostico-asientos'),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: !_hasSearched
                ? _buildEmptyState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabDesbalanceados(),
                      _buildTabCuentasInexistentes(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Diagnóstico Contable',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Detecta asientos desbalanceados y cuentas no encontradas en el plan de cuentas.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDesde,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha Desde',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_dateFmt.format(_fechaDesde)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _pickHasta,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha Hasta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_dateFmt.format(_fechaHasta)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _consultar,
                icon: const Icon(Icons.search),
                label: const Text('Consultar'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bug_report, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Seleccione el período y presione Consultar',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ---------- Tab 1: Asientos desbalanceados ----------

  Widget _buildTabDesbalanceados() {
    final async = ref.watch(asientosDesbalanceadosProvider(_params));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildError(e),
      data: (filas) => _buildTablaDesbalanceados(filas),
    );
  }

  Widget _buildTablaDesbalanceados(List<AsientoDesbalanceado> filas) {
    if (filas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No hay asientos desbalanceados en el período',
              style: TextStyle(color: Colors.green, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildResumenBanner(
          icon: Icons.warning_amber_rounded,
          color: Colors.orange[700]!,
          mensaje:
              '${filas.length} asiento(s) con diferencia entre Debe y Haber',
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 36,
                headingRowColor:
                    WidgetStateProperty.all(Colors.orange[100]),
                columns: const [
                  DataColumn(
                      label: Text('Asiento',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true),
                  DataColumn(
                      label: Text('Fecha',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Tipo',
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
                      label: Text('Diferencia',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red)),
                      numeric: true),
                ],
                rows: filas.map((f) {
                  return DataRow(cells: [
                    DataCell(Text(f.asiento.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(_dateFmt.format(f.fecha))),
                    DataCell(Text(AsientoDesbalanceado.nombreTipo(f.tipoAsiento))),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          f.detalle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(
                      _currency.format(f.totalDebe),
                      style: const TextStyle(color: Colors.green),
                    )),
                    DataCell(Text(
                      _currency.format(f.totalHaber),
                      style: const TextStyle(color: Colors.red),
                    )),
                    DataCell(Text(
                      _currency.format(f.diferencia),
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Tab 2: Cuentas inexistentes ----------

  Widget _buildTabCuentasInexistentes() {
    final async = ref.watch(cuentasInexistentesProvider(_params));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildError(e),
      data: (filas) => _buildTablaCuentasInexistentes(filas),
    );
  }

  Widget _buildTablaCuentasInexistentes(List<CuentaInexistente> filas) {
    if (filas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Todas las cuentas usadas existen en el plan de cuentas',
              style: TextStyle(color: Colors.green, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildResumenBanner(
          icon: Icons.search_off,
          color: Colors.red[700]!,
          mensaje:
              '${filas.length} cuenta(s) usadas en asientos que no existen en el plan de cuentas',
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 20,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 36,
                headingRowColor: WidgetStateProperty.all(Colors.red[100]),
                columns: const [
                  DataColumn(
                      label: Text('Cuenta ID',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true),
                  DataColumn(
                      label: Text('Usos',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true),
                  DataColumn(
                      label: Text('Primer asiento',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true),
                  DataColumn(
                      label: Text('Última fecha',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: filas.map((f) {
                  return DataRow(cells: [
                    DataCell(Text(
                      f.cuentaId.toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red),
                    )),
                    DataCell(Text(f.cantidadUsos.toString())),
                    DataCell(Text(f.primerAsiento.toString())),
                    DataCell(Text(
                      f.ultimaFecha != null
                          ? _dateFmt.format(f.ultimaFecha!)
                          : '-',
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Helpers ----------

  Widget _buildResumenBanner({
    required IconData icon,
    required Color color,
    required String mensaje,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $e'),
        ],
      ),
    );
  }
}
