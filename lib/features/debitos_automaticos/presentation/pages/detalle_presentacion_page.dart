import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/presentacion_tarjeta.dart';
import '../../providers/presentaciones_tarjetas_provider.dart';

class DetallePresentacionPage extends ConsumerWidget {
  final PresentacionTarjeta presentacion;

  const DetallePresentacionPage({
    required this.presentacion,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat =
        NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

    final params = DetalleParams(
      tarjetaId: presentacion.tarjetaId,
      periodo: presentacion.periodo,
    );
    final detalleAsync = ref.watch(detallePresentacionProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Detalle – ${presentacion.nombreTarjeta} ${dateFormat.format(presentacion.fechaPresentacion)}'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Resumen cabecera ─────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _infoChip(
                    label: 'Total',
                    value: currencyFormat.format(presentacion.total),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  if (presentacion.comision != null) ...[
                    _infoChip(
                      label: 'Comisión',
                      value: currencyFormat.format(presentacion.comision!),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (presentacion.neto != null) ...[
                    _infoChip(
                      label: 'Neto',
                      value: currencyFormat.format(presentacion.neto!),
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (presentacion.fechaAcreditacion != null) ...[
                    _infoChip(
                      label: 'Acreditado',
                      value: dateFormat.format(presentacion.fechaAcreditacion!),
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Chip(
                    label: Text(
                      presentacion.procesado ? 'Procesado' : 'Pendiente',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor:
                        presentacion.procesado ? Colors.green : Colors.orange,
                  ),
                ],
              ),
            ),
          ),

          // ── Tabla de detalle ─────────────────────────────────────────────
          Expanded(
            child: detalleAsync.when(
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
                  ],
                ),
              ),
              data: (detalles) {
                if (detalles.isEmpty) {
                  return const Center(
                    child: Text('No hay detalle para esta presentación'),
                  );
                }
                return _buildTabla(detalles, currencyFormat);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTabla(
      List<DetallePresentacion> detalles, NumberFormat currencyFormat) {
    final totalImporte =
        detalles.fold<double>(0.0, (sum, d) => sum + d.importe);

    return SingleChildScrollView(
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor:
                  WidgetStateProperty.all(Colors.purple.shade50),
              columns: const [
                DataColumn(label: Text('Socio ID')),
                DataColumn(label: Text('Apellido y Nombre')),
                DataColumn(label: Text('Importe'), numeric: true),
                DataColumn(label: Text('Nro Tarjeta')),
              ],
              rows: detalles
                  .map((d) => DataRow(cells: [
                        DataCell(Text(d.socioId.toString())),
                        DataCell(Text(d.nombreCompleto)),
                        DataCell(
                            Text(currencyFormat.format(d.importe))),
                        DataCell(Text(d.numeroTarjetaEnmascarado)),
                      ]))
                  .toList(),
            ),
          ),
          // Pie con totales
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${detalles.length} socios  |  Total: ${currencyFormat.format(totalImporte)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
