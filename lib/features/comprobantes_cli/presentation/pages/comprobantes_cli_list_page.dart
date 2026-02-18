import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/comprobantes_cli_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../../core/utils/date_picker_utils.dart';

class ComprobantesCliListPage extends ConsumerStatefulWidget {
  final int? clienteId;

  const ComprobantesCliListPage({super.key, this.clienteId});

  @override
  ConsumerState<ComprobantesCliListPage> createState() =>
      _ComprobantesCliListPageState();
}

class _ComprobantesCliListPageState
    extends ConsumerState<ComprobantesCliListPage> {
  final _clienteController = TextEditingController();
  final _nroComprobanteController = TextEditingController();
  bool _initialized = false;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  @override
  void initState() {
    super.initState();
    if (widget.clienteId != null) {
      _clienteController.text = widget.clienteId.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(venCliSearchStateProvider.notifier)
            .updateClienteCodigo(widget.clienteId.toString());
        _performSearch();
      });
    }
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _nroComprobanteController.dispose();
    super.dispose();
  }

  void _syncControllersFromState(VenCliSearchState searchState) {
    if (!_initialized && widget.clienteId == null) {
      _clienteController.text = searchState.clienteCodigo;
      _nroComprobanteController.text = searchState.nroComprobante;
      _initialized = true;
    }
  }

  Future<void> _performSearch() async {
    final notifier = ref.read(venCliSearchStateProvider.notifier);

    notifier.updateClienteCodigo(_clienteController.text.trim());
    notifier.updateNroComprobante(_nroComprobanteController.text.trim());

    notifier.clearResults();

    final searchState = ref.read(venCliSearchStateProvider);

    try {
      final comprobantes = await ref.read(
          comprobantesCliSearchProvider(searchState.toSearchParams()).future);
      notifier.setResultados(comprobantes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en búsqueda: $e')),
        );
      }
    }
  }

  void _clearSearch() {
    _clienteController.clear();
    _nroComprobanteController.clear();
    ref.read(venCliSearchStateProvider.notifier).clearSearch();
  }

  Future<void> _selectFechaDesde() async {
    final searchState = ref.read(venCliSearchStateProvider);
    final fecha = await pickDate(context, searchState.fechaDesde ?? DateTime.now());
    if (fecha != null) {
      ref.read(venCliSearchStateProvider.notifier).updateFechaDesde(fecha);
    }
  }

  Future<void> _selectFechaHasta() async {
    final searchState = ref.read(venCliSearchStateProvider);
    final fecha = await pickDate(context, searchState.fechaHasta ?? DateTime.now());
    if (fecha != null) {
      ref.read(venCliSearchStateProvider.notifier).updateFechaHasta(fecha);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(venCliSearchStateProvider);
    final tiposAsync = ref.watch(tiposComprobanteVentaProvider);

    _syncControllersFromState(searchState);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clienteId != null
            ? 'Comprobantes del Cliente'
            : 'Comprobantes de Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: widget.clienteId == null
          ? const AppDrawer(currentRoute: '/comprobantes-clientes')
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (widget.clienteId != null) {
            context
                .go('/comprobantes-clientes/nuevo?cliente=${widget.clienteId}');
          } else {
            context.go('/comprobantes-clientes/nuevo');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Comprobante'),
      ),
      body: Column(
        children: [
          // Formulario de búsqueda
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Búsqueda de Comprobantes',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _clienteController,
                            decoration: const InputDecoration(
                              labelText: 'Cód. Cliente',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                            ),
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nroComprobanteController,
                            decoration: const InputDecoration(
                              labelText: 'Nro. Comprobante',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.receipt),
                            ),
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: tiposAsync.when(
                            data: (tipos) => DropdownButtonFormField<int?>(
                              initialValue: searchState.tipoComprobante,
                              decoration: const InputDecoration(
                                labelText: 'Tipo Comprobante',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Todos'),
                                ),
                                ...tipos.map((tipo) => DropdownMenuItem<int?>(
                                      value: tipo.codigo,
                                      child: Text(tipo.descripcion),
                                    )),
                              ],
                              onChanged: (value) {
                                ref
                                    .read(venCliSearchStateProvider.notifier)
                                    .updateTipoComprobante(value);
                              },
                            ),
                            loading: () => const TextField(
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'Cargando...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            error: (_, __) => const TextField(
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'Error cargando tipos',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectFechaDesde,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Fecha Desde',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.calendar_today),
                                suffixIcon: searchState.fechaDesde != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          ref
                                              .read(venCliSearchStateProvider
                                                  .notifier)
                                              .updateFechaDesde(null);
                                        },
                                      )
                                    : null,
                              ),
                              child: Text(
                                searchState.fechaDesde != null
                                    ? _dateFormat
                                        .format(searchState.fechaDesde!)
                                    : '',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: _selectFechaHasta,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Fecha Hasta',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.calendar_today),
                                suffixIcon: searchState.fechaHasta != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          ref
                                              .read(venCliSearchStateProvider
                                                  .notifier)
                                              .updateFechaHasta(null);
                                        },
                                      )
                                    : null,
                              ),
                              child: Text(
                                searchState.fechaHasta != null
                                    ? _dateFormat
                                        .format(searchState.fechaHasta!)
                                    : '',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CheckboxListTile(
                            value: searchState.soloConSaldo,
                            title: const Text('Solo con saldo'),
                            onChanged: (value) {
                              ref
                                  .read(venCliSearchStateProvider.notifier)
                                  .updateSoloConSaldo(value ?? false);
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.icon(
                          onPressed: _performSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Resultados
          Expanded(
            child: !searchState.hasSearched
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Utilice los filtros para buscar comprobantes',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildSearchResults(searchState),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(VenCliSearchState searchState) {
    final comprobantes = searchState.resultados;

    if (comprobantes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No se encontraron comprobantes'),
            SizedBox(height: 8),
            Text(
              'Intenta con otros criterios de búsqueda',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Calcular totales
    double totalImportes = 0;
    double totalSaldos = 0;
    for (final comp in comprobantes) {
      totalImportes += comp.totalImporte;
      totalSaldos += comp.saldo;
    }

    return Column(
      children: [
        // Resumen
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.green[50],
          child: Row(
            children: [
              Text(
                '${comprobantes.length} comprobante(s)',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                'Total: ${_currencyFormat.format(totalImportes)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 24),
              Text(
                'Saldo: ${_currencyFormat.format(totalSaldos)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: totalSaldos > 0 ? Colors.green[700] : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        // Lista
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: comprobantes.length,
            itemBuilder: (context, index) {
              final comp = comprobantes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        comp.estaCancelado ? Colors.green : Colors.blue,
                    child: Icon(
                      comp.estaCancelado ? Icons.check : Icons.pending_actions,
                      color: Colors.white,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        comp.nroComprobante ?? 'S/N',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      if (comp.tipoFactura != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            comp.tipoFactura!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (comp.clienteNombre != null) Text(comp.clienteNombre!),
                      Text('Fecha: ${_dateFormat.format(comp.fecha)}'),
                      Row(
                        children: [
                          Text(
                              'Total: ${_currencyFormat.format(comp.totalImporte)}'),
                          const SizedBox(width: 16),
                          if (!comp.estaCancelado)
                            Text(
                              'Saldo: ${_currencyFormat.format(comp.saldo)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        onPressed: () {
                          context.go(
                              '/comprobantes-clientes/${comp.idTransaccion}');
                        },
                        tooltip: 'Ver detalle',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () {
                          context.go(
                              '/comprobantes-clientes/${comp.idTransaccion}/editar');
                        },
                        tooltip: 'Editar',
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
