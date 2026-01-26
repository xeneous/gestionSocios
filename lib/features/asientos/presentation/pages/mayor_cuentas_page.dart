import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../cuentas/providers/cuentas_provider.dart';
import '../../../cuentas/models/cuenta_model.dart';

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
  int get hashCode => cuenta.hashCode ^ fechaDesde.hashCode ^ fechaHasta.hashCode ^ acumulado.hashCode;
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
final mayorCuentaProvider = FutureProvider.family<MayorCuentaResult, MayorCuentaParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  final fechaDesdeStr = params.fechaDesde.toIso8601String().split('T')[0];
  final fechaHastaStr = params.fechaHasta.toIso8601String().split('T')[0];

  // Calcular saldo inicial si es acumulado
  double saldoInicial = 0;
  if (params.acumulado) {
    final saldosAnterioresResponse = await supabase
        .from('asientos_items')
        .select('''
          debe,
          haber,
          asientos_header!inner(fecha)
        ''')
        .eq('cuenta_id', params.cuenta)
        .lt('asientos_header.fecha', fechaDesdeStr);

    for (final mov in saldosAnterioresResponse as List) {
      final debe = (mov['debe'] as num?)?.toDouble() ?? 0;
      final haber = (mov['haber'] as num?)?.toDouble() ?? 0;
      saldoInicial += debe - haber;
    }
  }

  // Obtener movimientos del período
  final movimientosResponse = await supabase
      .from('asientos_items')
      .select('''
        debe,
        haber,
        detalle,
        asientos_header!inner(fecha, asiento, detalle)
      ''')
      .eq('cuenta_id', params.cuenta)
      .gte('asientos_header.fecha', fechaDesdeStr)
      .lte('asientos_header.fecha', fechaHastaStr)
      .order('asientos_header(fecha)', ascending: true);

  final movimientos = <MovimientoCuenta>[];
  for (final mov in movimientosResponse as List) {
    final header = mov['asientos_header'] as Map<String, dynamic>;
    movimientos.add(MovimientoCuenta(
      fecha: DateTime.parse(header['fecha'] as String),
      asiento: header['asiento'] as int,
      detalle: mov['detalle'] as String? ?? header['detalle'] as String? ?? '',
      debe: (mov['debe'] as num?)?.toDouble() ?? 0,
      haber: (mov['haber'] as num?)?.toDouble() ?? 0,
    ));
  }

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
  bool _hasSearched = false;
  int? _cuentaSeleccionada;
  String? _cuentaDescripcion;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaDesde = DateTime(now.year, now.month, 1);
    _fechaHasta = DateTime(now.year, now.month + 1, 0);
  }

  @override
  void dispose() {
    _cuentaController.dispose();
    super.dispose();
  }

  Future<void> _selectFechaDesde() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaDesde,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      setState(() => _fechaDesde = fecha);
    }
  }

  Future<void> _selectFechaHasta() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHasta,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      setState(() => _fechaHasta = fecha);
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
    setState(() => _hasSearched = true);
  }

  MayorCuentaParams? get _params => _cuentaSeleccionada == null
      ? null
      : MayorCuentaParams(
          cuenta: _cuentaSeleccionada!,
          fechaDesde: _fechaDesde,
          fechaHasta: _fechaHasta,
          acumulado: _acumulado,
        );

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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    const SizedBox(width: 16),
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
                          color: mayor.saldoFinal >= 0 ? Colors.blue : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tabla de movimientos
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Asiento', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Detalle', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Debe', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text('Haber', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text('Saldo', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    ],
                    rows: _buildRows(mayor),
                  ),
                ),
              ),
            ),
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

  List<DataRow> _buildRows(MayorCuentaResult mayor) {
    final rows = <DataRow>[];
    double saldoAcumulado = mayor.saldoInicial;

    // Fila de saldo inicial si es acumulado
    if (_acumulado && mayor.saldoInicial != 0) {
      rows.add(DataRow(
        color: WidgetStateProperty.all(Colors.blue[50]),
        cells: [
          DataCell(Text(_dateFormat.format(_fechaDesde))),
          const DataCell(Text('-')),
          const DataCell(Text('SALDO INICIAL', style: TextStyle(fontStyle: FontStyle.italic))),
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
    for (final mov in mayor.movimientos) {
      saldoAcumulado += mov.debe - mov.haber;
      rows.add(DataRow(
        cells: [
          DataCell(Text(_dateFormat.format(mov.fecha))),
          DataCell(Text(mov.asiento.toString())),
          DataCell(Text(mov.detalle)),
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

    // Fila de totales
    rows.add(DataRow(
      color: WidgetStateProperty.all(Colors.grey[200]),
      cells: [
        const DataCell(Text('TOTALES', style: TextStyle(fontWeight: FontWeight.bold))),
        const DataCell(Text('')),
        const DataCell(Text('')),
        DataCell(Text(
          _currencyFormat.format(mayor.totalDebe),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        )),
        DataCell(Text(
          _currencyFormat.format(mayor.totalHaber),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        )),
        DataCell(Text(
          _currencyFormat.format(mayor.saldoFinal),
          style: const TextStyle(fontWeight: FontWeight.bold),
        )),
      ],
    ));

    return rows;
  }
}

/// Diálogo para buscar y seleccionar una cuenta contable
class _CuentaSearchDialog extends ConsumerStatefulWidget {
  const _CuentaSearchDialog();

  @override
  ConsumerState<_CuentaSearchDialog> createState() => _CuentaSearchDialogState();
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
      cuentasSearchProvider(CuentasSearchParams(searchTerm: _searchTerm.isEmpty ? null : _searchTerm)),
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
