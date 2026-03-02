import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cuentas_corrientes/models/concepto_tesoreria_model.dart';
import '../../../cuentas_corrientes/providers/conceptos_tesoreria_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../../core/utils/web_utils.dart';

// ============================================================================
// MODELO
// ============================================================================

class MovimientoTesoreria {
  final int id;
  final DateTime fecha;
  final String concepto;
  final double importe; // positivo = débito (ingreso), negativo = crédito (egreso)
  final int tipoMovimiento; // 1 = ingreso, 2 = egreso
  final String? observaciones;
  final int? numeroInterno;
  // Datos de la operación
  final String? tipoOperacion;
  final String? entidadTipo;
  final int? numeroComprobante;
  // Datos del asiento
  final int? asientoNumero;
  final int? asientoTipo;
  // Datos adicionales para filtros
  final String? banco;
  final int? conceptoId;

  MovimientoTesoreria({
    required this.id,
    required this.fecha,
    required this.concepto,
    required this.importe,
    required this.tipoMovimiento,
    this.observaciones,
    this.numeroInterno,
    this.tipoOperacion,
    this.entidadTipo,
    this.numeroComprobante,
    this.asientoNumero,
    this.asientoTipo,
    this.banco,
    this.conceptoId,
  });

  bool get esBanco => banco != null && banco!.isNotEmpty;
  bool get esEfectivo => banco == null || banco!.isEmpty;
  bool get esDebito => importe > 0;
  double get debito => importe > 0 ? importe : 0;
  double get credito => importe < 0 ? importe.abs() : 0;
}

// ============================================================================
// PROVIDER
// ============================================================================

class TesoreriaDiariaParams {
  final DateTime fechaDesde;
  final DateTime fechaHasta;

  const TesoreriaDiariaParams({
    required this.fechaDesde,
    required this.fechaHasta,
  });

  @override
  bool operator ==(Object other) =>
      other is TesoreriaDiariaParams &&
      fechaDesde == other.fechaDesde &&
      fechaHasta == other.fechaHasta;

  @override
  int get hashCode => Object.hash(fechaDesde, fechaHasta);
}

final tesoreriaDiariaProvider = FutureProvider.family<
    List<MovimientoTesoreria>,
    TesoreriaDiariaParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  // 1. Obtener movimientos de valores_tesoreria con conceptos
  final response = await supabase
      .from('valores_tesoreria')
      .select('id, tipo_movimiento, fecha_emision, importe, numero_interno, observaciones, banco, idconcepto_tesoreria, conceptos_tesoreria(descripcion)')
      .gte('fecha_emision', params.fechaDesde.toIso8601String().split('T')[0])
      .lte('fecha_emision', '${params.fechaHasta.toIso8601String().split('T')[0]}T23:59:59')
      .order('fecha_emision', ascending: false);

  if ((response as List).isEmpty) return [];

  final valorIds = response.map((v) => v['id'] as int).toList();

  // 2. Obtener datos de operaciones_contables vinculados (asiento + tipo operación)
  final detallesResponse = await supabase
      .from('operaciones_detalle_valores_tesoreria')
      .select('valor_tesoreria_id, operaciones_contables(tipo_operacion, entidad_tipo, numero_comprobante, asiento_numero, asiento_tipo)')
      .inFilter('valor_tesoreria_id', valorIds);

  // Construir mapa valorId → operacion
  final operacionMap = <int, Map<String, dynamic>>{};
  for (final d in detallesResponse as List) {
    final valorId = d['valor_tesoreria_id'] as int;
    final op = d['operaciones_contables'] as Map<String, dynamic>?;
    if (op != null) {
      operacionMap[valorId] = op;
    }
  }

  // 3. Construir lista de movimientos
  return response.map((v) {
    final valorId = v['id'] as int;
    final op = operacionMap[valorId];
    final concepto = (v['conceptos_tesoreria'] as Map<String, dynamic>?)?['descripcion'] as String? ?? 'Sin concepto';

    return MovimientoTesoreria(
      id: valorId,
      fecha: DateTime.parse(v['fecha_emision'].toString()),
      concepto: concepto,
      importe: (v['importe'] as num).toDouble(),
      tipoMovimiento: v['tipo_movimiento'] as int? ?? 1,
      observaciones: v['observaciones'] as String?,
      numeroInterno: v['numero_interno'] as int?,
      tipoOperacion: op?['tipo_operacion'] as String?,
      entidadTipo: op?['entidad_tipo'] as String?,
      numeroComprobante: op?['numero_comprobante'] as int?,
      asientoNumero: op?['asiento_numero'] as int?,
      asientoTipo: op?['asiento_tipo'] as int?,
      banco: v['banco'] as String?,
      conceptoId: v['idconcepto_tesoreria'] as int?,
    );
  }).toList();
});

// ============================================================================
// PAGE
// ============================================================================

class TesoreriaDiariaPage extends ConsumerStatefulWidget {
  const TesoreriaDiariaPage({super.key});

  @override
  ConsumerState<TesoreriaDiariaPage> createState() => _TesoreriaDiariaPageState();
}

class _TesoreriaDiariaPageState extends ConsumerState<TesoreriaDiariaPage> {
  late DateTime _fechaDesde;
  late DateTime _fechaHasta;
  // Filtros adicionales: 'todos' | 'banco' | 'efectivo' | 'concepto'
  String _filtroTipo = 'todos';
  int? _filtroConceptoId;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  static const _tiposAsiento = {
    0: 'Diario',
    1: 'Ingreso',
    2: 'Egreso',
    3: 'Compras',
    4: 'Ventas',
  };

  static const _tiposOperacion = {
    'COBRANZA_SOCIO': 'Cob. Socio',
    'COBRANZA_SPONSOR': 'Cob. Sponsor',
    'COBRANZA_PROFESIONAL': 'Cob. Profesional',
    'ORDEN_PAGO': 'Orden de Pago',
    'FACTURA_COMPRA': 'Factura Compra',
    'FACTURA_VENTA': 'Factura Venta',
    'DEBITO_AUTOMATICO': 'Débito Automático',
    'NOTA_CREDITO': 'Nota Crédito',
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaDesde = DateTime(now.year, now.month, now.day);
    _fechaHasta = DateTime(now.year, now.month, now.day);
  }

  TesoreriaDiariaParams get _params => TesoreriaDiariaParams(
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
      );

  @override
  Widget build(BuildContext context) {
    final movimientosAsync = ref.watch(tesoreriaDiariaProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tesorería Diaria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Abrir en nueva pestaña',
            onPressed: () => abrirEnNuevaPestana('/tesoreria'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(tesoreriaDiariaProvider(_params)),
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/tesoreria-diaria'),
      body: Column(
        children: [
          _buildFiltros(),
          const Divider(height: 1),
          Expanded(child: _buildContenido(movimientosAsync)),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    final conceptosAsync = ref.watch(conceptosTesoreriaProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: título, fechas, accesos rápidos
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.blueGrey),
              const SizedBox(width: 8),
              const Text(
                'Movimientos de Tesorería',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _buildDatePicker(
                label: 'Desde',
                fecha: _fechaDesde,
                onChanged: (d) => setState(() => _fechaDesde = d),
              ),
              const SizedBox(width: 12),
              _buildDatePicker(
                label: 'Hasta',
                fecha: _fechaHasta,
                onChanged: (d) => setState(() => _fechaHasta = d),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  final now = DateTime.now();
                  setState(() {
                    _fechaDesde = DateTime(now.year, now.month, now.day);
                    _fechaHasta = DateTime(now.year, now.month, now.day);
                  });
                },
                child: const Text('Hoy'),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () {
                  final now = DateTime.now();
                  setState(() {
                    _fechaDesde = DateTime(now.year, now.month, 1);
                    _fechaHasta = DateTime(now.year, now.month + 1, 0);
                  });
                },
                child: const Text('Este mes'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Fila 2: filtros por tipo / concepto
          Row(
            children: [
              const Text(
                'Filtrar por:',
                style: TextStyle(fontSize: 13, color: Colors.blueGrey),
              ),
              const SizedBox(width: 12),
              // Chips: Todos / Efectivo / Banco / Por concepto
              _buildFiltroChip('todos', 'Todos'),
              const SizedBox(width: 6),
              _buildFiltroChip('concepto', 'Por concepto'),
              // Dropdown de conceptos (visible sólo cuando filtro = 'concepto')
              if (_filtroTipo == 'concepto') ...[
                const SizedBox(width: 12),
                conceptosAsync.when(
                  data: (conceptos) => SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<int?>(
                      value: _filtroConceptoId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Concepto',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Todos los conceptos'),
                        ),
                        ...conceptos.map((c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.descripcion ?? 'Concepto ${c.id}'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _filtroConceptoId = v),
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const Text('Error cargando conceptos'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String tipo, String label) {
    final selected = _filtroTipo == tipo;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _filtroTipo = tipo;
        if (tipo != 'concepto') _filtroConceptoId = null;
      }),
      selectedColor: Colors.blueGrey[200],
      checkmarkColor: Colors.blueGrey[800],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime fecha,
    required ValueChanged<DateTime> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: fecha,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          locale: const Locale('es', 'AR'),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${_dateFormat.format(fecha)}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido(AsyncValue<List<MovimientoTesoreria>> movimientosAsync) {
    return movimientosAsync.when(
      data: (movimientos) {
        // Aplicar filtros client-side
        final movimientosFiltrados = movimientos.where((m) {
          switch (_filtroTipo) {
            case 'banco':
              return m.esBanco;
            case 'efectivo':
              return m.esEfectivo;
            case 'concepto':
              return _filtroConceptoId == null || m.conceptoId == _filtroConceptoId;
            default:
              return true;
          }
        }).toList();

        if (movimientosFiltrados.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No hay movimientos para los filtros seleccionados'),
              ],
            ),
          );
        }

        // Agrupar por fecha
        final porDia = <String, List<MovimientoTesoreria>>{};
        for (final m in movimientosFiltrados) {
          final clave = _dateFormat.format(m.fecha);
          porDia.putIfAbsent(clave, () => []).add(m);
        }

        // Totales generales (del filtro aplicado)
        final totalDebitos = movimientosFiltrados.fold(0.0, (s, m) => s + m.debito);
        final totalCreditos = movimientosFiltrados.fold(0.0, (s, m) => s + m.credito);

        return Column(
          children: [
            // Resumen general
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[200],
              child: Row(
                children: [
                  Text('${movimientosFiltrados.length} movimiento(s) · ${porDia.length} día(s)'),
                  const Spacer(),
                  Text(
                    'Total Débitos: ${_currencyFormat.format(totalDebitos)}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    'Total Créditos: ${_currencyFormat.format(totalCreditos)}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    'Neto: ${_currencyFormat.format(totalDebitos - totalCreditos)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (totalDebitos - totalCreditos) >= 0 ? Colors.green[700] : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            // Lista por día
            Expanded(
              child: ListView.builder(
                itemCount: porDia.length,
                itemBuilder: (context, index) {
                  final dia = porDia.keys.elementAt(index);
                  final movsDia = porDia[dia]!;
                  final debitosDia = movsDia.fold(0.0, (s, m) => s + m.debito);
                  final creditosDia = movsDia.fold(0.0, (s, m) => s + m.credito);

                  return _buildDiaSection(dia, movsDia, debitosDia, creditosDia);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $e'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(tesoreriaDiariaProvider(_params)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaSection(
    String dia,
    List<MovimientoTesoreria> movimientos,
    double debitos,
    double creditos,
  ) {
    final neto = debitos - creditos;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // Header del día
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blueGrey[700],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  dia,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  'Débitos: ${_currencyFormat.format(debitos)}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                ),
                const SizedBox(width: 16),
                Text(
                  'Créditos: ${_currencyFormat.format(creditos)}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
                const SizedBox(width: 16),
                Text(
                  'Neto: ${_currencyFormat.format(neto)}',
                  style: TextStyle(
                    color: neto >= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Tabla de movimientos del día
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 16,
              headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
              columns: const [
                DataColumn(label: Text('Concepto', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Detalle', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Tipo Op.', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Débito', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Crédito', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Asiento', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: movimientos.map((m) => _buildRow(m)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(MovimientoTesoreria m) {
    final tipoOpLabel = m.tipoOperacion != null
        ? (_tiposOperacion[m.tipoOperacion] ?? m.tipoOperacion!)
        : '-';

    final detalle = m.observaciones?.isNotEmpty == true
        ? m.observaciones!
        : m.numeroInterno != null
            ? 'Nro. ${m.numeroInterno}'
            : '-';

    String asientoLabel = '-';
    if (m.asientoNumero != null) {
      final tipoAsientoDesc = m.asientoTipo != null
          ? (_tiposAsiento[m.asientoTipo] ?? 'Tipo ${m.asientoTipo}')
          : '';
      asientoLabel = '${m.asientoNumero}${tipoAsientoDesc.isNotEmpty ? ' ($tipoAsientoDesc)' : ''}';
    }

    return DataRow(
      color: WidgetStateProperty.all(m.esDebito ? Colors.green[50] : Colors.red[50]),
      cells: [
        DataCell(Text(m.concepto)),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(detalle, overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: m.esDebito ? Colors.green[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(tipoOpLabel, style: const TextStyle(fontSize: 12)),
          ),
        ),
        DataCell(
          Text(
            m.debito > 0 ? _currencyFormat.format(m.debito) : '-',
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DataCell(
          Text(
            m.credito > 0 ? _currencyFormat.format(m.credito) : '-',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(
          m.asientoNumero != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.book, size: 14, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    Text(asientoLabel, style: const TextStyle(fontSize: 13)),
                  ],
                )
              : const Text('-', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
