import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/comprobantes_cli_provider.dart';
import '../../models/comprobante_cli_model.dart';
import '../../../clientes/providers/clientes_provider.dart';

/// Página de cuenta corriente de cliente (A COBRAR)
/// Saldo positivo = el cliente nos debe
class CuentaCorrienteClientePage extends ConsumerStatefulWidget {
  final int clienteId;

  const CuentaCorrienteClientePage({
    super.key,
    required this.clienteId,
  });

  @override
  ConsumerState<CuentaCorrienteClientePage> createState() =>
      _CuentaCorrienteClientePageState();
}

class _CuentaCorrienteClientePageState
    extends ConsumerState<CuentaCorrienteClientePage> {
  bool _soloConSaldo = true;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  @override
  Widget build(BuildContext context) {
    final clienteAsync = ref.watch(clienteProvider(widget.clienteId));
    final tiposAsync = ref.watch(tiposComprobanteVentaProvider);

    final searchParams = VenCliSearchParams(
      cliente: widget.clienteId,
      soloConSaldo: _soloConSaldo,
    );
    final comprobantesAsync = ref.watch(comprobantesCliSearchProvider(searchParams));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver a Clientes',
          onPressed: () => context.go('/clientes'),
        ),
        title: clienteAsync.when(
          data: (cli) => Text('Cta. Cte. - ${cli?.razonSocial ?? cli?.nombreCompleto ?? "Cliente"}'),
          loading: () => const Text('Cuenta Corriente'),
          error: (_, __) => const Text('Cuenta Corriente'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Inicio',
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo Comprobante',
            onPressed: () {
              context.go('/comprobantes-clientes/nuevo?cliente=${widget.clienteId}');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con info del cliente y saldo
          _buildInfoHeader(clienteAsync, comprobantesAsync),

          const Divider(height: 1),

          // Filtro
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _soloConSaldo,
                  onChanged: (value) {
                    setState(() => _soloConSaldo = value ?? false);
                  },
                ),
                const Text('Solo con saldo pendiente'),
                const Spacer(),
                Text(
                  'A COBRAR',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Tabla de comprobantes
          Expanded(
            child: _buildComprobantesTable(comprobantesAsync, tiposAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHeader(
    AsyncValue clienteAsync,
    AsyncValue<List<VenCliHeader>> comprobantesAsync,
  ) {
    // Calcular totales
    double totalFacturado = 0;
    double totalCobrado = 0;
    int cantidadComprobantes = 0;

    if (comprobantesAsync.hasValue) {
      final comprobantes = comprobantesAsync.value!;
      cantidadComprobantes = comprobantes.length;
      for (final comp in comprobantes) {
        totalFacturado += comp.totalImporte;
        totalCobrado += comp.cancelado;
      }
    }

    final saldoPendiente = totalFacturado - totalCobrado;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.green[50],
      child: Row(
        children: [
          Expanded(
            child: clienteAsync.when(
              data: (cli) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cli?.codigo} - ${cli?.razonSocial ?? cli?.nombreCompleto}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (cli?.cuit != null && cli!.cuit!.isNotEmpty)
                    Text(
                      'CUIT: ${cli.cuit}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                ],
              ),
              loading: () => const Text('Cargando...'),
              error: (_, __) => const Text('Error cargando cliente'),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Saldo a Cobrar: ${_currencyFormat.format(saldoPendiente)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: saldoPendiente > 0 ? Colors.green[700] : Colors.grey,
                ),
              ),
              Text(
                '$cantidadComprobantes comprobante(s)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComprobantesTable(
    AsyncValue<List<VenCliHeader>> comprobantesAsync,
    AsyncValue<List<TipoComprobanteVenta>> tiposAsync,
  ) {
    return comprobantesAsync.when(
      data: (comprobantes) {
        if (comprobantes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _soloConSaldo
                      ? 'No hay comprobantes con saldo pendiente'
                      : 'No hay comprobantes registrados',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Crear mapa de tipos para descripción
        final tiposMap = <int, TipoComprobanteVenta>{};
        if (tiposAsync.hasValue) {
          for (final tipo in tiposAsync.value!) {
            tiposMap[tipo.codigo] = tipo;
          }
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 16,
              headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
              columns: const [
                DataColumn(
                    label: Text('Fecha',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Tipo',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Nro. Comprobante',
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
                DataColumn(
                    label: Text('Vencimiento',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Acciones',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _buildRows(comprobantes, tiposMap),
            ),
          ),
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

  List<DataRow> _buildRows(
    List<VenCliHeader> comprobantes,
    Map<int, TipoComprobanteVenta> tiposMap,
  ) {
    double saldoAcumulado = 0;
    final rows = <DataRow>[];

    // Ordenar por fecha ascendente para calcular saldo acumulado
    final sorted = List<VenCliHeader>.from(comprobantes)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    for (final comp in sorted) {
      final tipo = tiposMap[comp.tipoComprobante];
      final multiplicador = tipo?.multiplicador ?? 1;

      // Para clientes (a cobrar):
      // Facturas (multiplicador 1) = aumenta crédito a favor nuestro (debe)
      // NC/Cobros (multiplicador -1) = disminuye crédito (haber)
      final importe = _soloConSaldo ? comp.saldo : comp.totalImporte;
      final debe = multiplicador == 1 ? importe : 0.0;
      final haber = multiplicador == -1 ? importe : 0.0;

      saldoAcumulado += debe - haber;

      final isPendiente = comp.saldo > 0;
      final rowColor = isPendiente ? Colors.green[50] : null;

      final tipoDesc = tipo != null
          ? '${tipo.comprobante} - ${tipo.descripcion}'
          : 'Tipo ${comp.tipoComprobante}';

      rows.add(
        DataRow(
          color: WidgetStateProperty.all(rowColor),
          cells: [
            DataCell(Text(_dateFormat.format(comp.fecha))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tipoDesc),
                  if (comp.tipoFactura != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        comp.tipoFactura!,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            DataCell(Text(comp.nroComprobante ?? 'S/N')),
            DataCell(
              Text(
                debe > 0 ? _currencyFormat.format(debe) : '-',
                style: TextStyle(color: Colors.green[700]),
              ),
            ),
            DataCell(
              Text(
                haber > 0 ? _currencyFormat.format(haber) : '-',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            DataCell(
              Text(
                _currencyFormat.format(saldoAcumulado),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: saldoAcumulado > 0 ? Colors.green[700] : Colors.red,
                ),
              ),
            ),
            DataCell(
              Text(comp.fecha1Venc != null ? _dateFormat.format(comp.fecha1Venc!) : '-'),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 18, color: Colors.blue),
                    onPressed: () {
                      context.go('/comprobantes-clientes/${comp.idTransaccion}');
                    },
                    tooltip: 'Ver Detalle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.orange),
                    onPressed: () {
                      context.go('/comprobantes-clientes/${comp.idTransaccion}/editar');
                    },
                    tooltip: 'Editar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return rows;
  }
}
