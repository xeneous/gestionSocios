import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/cuentas_corrientes_provider.dart';
import '../../models/cuenta_corriente_completa_model.dart';
import '../../../socios/providers/socios_provider.dart';

/// Página para mostrar los movimientos de cuenta corriente de un socio específico
class CuentaCorrienteSocioPage extends ConsumerStatefulWidget {
  final int socioId;

  const CuentaCorrienteSocioPage({
    super.key,
    required this.socioId,
  });

  @override
  ConsumerState<CuentaCorrienteSocioPage> createState() =>
      _CuentaCorrienteSocioPageState();
}

class _CuentaCorrienteSocioPageState
    extends ConsumerState<CuentaCorrienteSocioPage> {
  bool _soloPendientes = false;

  @override
  Widget build(BuildContext context) {
    // Cargar información del socio
    final socioAsync = ref.watch(socioByIdProvider(widget.socioId));

    // Cargar saldo del socio
    final saldoAsync = ref.watch(saldoSocioProvider(widget.socioId));

    // Cargar movimientos
    final searchParams = CuentasCorrientesSearchParams(
      socioId: widget.socioId,
      soloPendientes: _soloPendientes,
    );
    final movimientosAsync = ref.watch(
      cuentasCorrientesSearchProvider(searchParams),
    );

    return Scaffold(
      appBar: AppBar(
        title: socioAsync.when(
          data: (socio) => Text('CC: ${socio?.apellido}, ${socio?.nombre}'),
          loading: () => const Text('Cuenta Corriente'),
          error: (_, __) => const Text('Cuenta Corriente'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navegar al formulario de nueva transacción con el socio pre-seleccionado
          context.go('/cuentas-corrientes/nueva?socioId=${widget.socioId}');
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva Transacción'),
      ),
      body: Column(
        children: [
          // Card con resumen de saldo
          _buildSaldoCard(socioAsync, saldoAsync),

          // Filtro solo pendientes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    value: _soloPendientes,
                    title: const Text('Solo pendientes de pago'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() => _soloPendientes = value ?? false);
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lista de movimientos
          Expanded(
            child: _buildMovimientosList(movimientosAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildSaldoCard(
    AsyncValue socioAsync,
    AsyncValue<Map<String, double>> saldoAsync,
  ) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            socioAsync.when(
              data: (socio) => Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      '${socio?.id}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${socio?.apellido}, ${socio?.nombre}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (socio?.numeroDocumento != null)
                          Text(
                            'DNI: ${socio.numeroDocumento}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error cargando socio'),
            ),
            const Divider(height: 24),
            saldoAsync.when(
              data: (saldo) {
                final saldoPendiente = saldo['saldo_pendiente'] ?? 0.0;
                final isDeudor = saldoPendiente > 0;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Saldo Total:',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          '\$${saldo['saldo_total']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Cancelado:',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          '\$${saldo['total_cancelado']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Saldo Pendiente:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${saldoPendiente.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDeudor ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (isDeudor)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning,
                                color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'El socio tiene deuda pendiente',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Total de transacciones: ${saldo['total_transacciones']?.toInt() ?? 0}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error cargando saldo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovimientosList(
    AsyncValue<List<CuentaCorrienteCompleta>> movimientosAsync,
  ) {
    return movimientosAsync.when(
      data: (movimientos) {
        if (movimientos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _soloPendientes
                      ? 'No hay movimientos pendientes'
                      : 'No hay movimientos registrados',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: movimientos.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${movimientos.length} movimiento(s) encontrado(s)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            final cuenta = movimientos[index - 1];
            return _buildMovimientoCard(cuenta);
          },
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(cuentasCorrientesSearchProvider);
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovimientoCard(CuentaCorrienteCompleta cuenta) {
    final isPendiente = !cuenta.header.estaCancelado;
    final isVencido = cuenta.header.estaVencido;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isPendiente
              ? (isVencido ? Colors.red : Colors.orange)
              : Colors.green,
          child: Icon(
            isPendiente
                ? (isVencido ? Icons.warning : Icons.pending)
                : Icons.check_circle,
            color: Colors.white,
          ),
        ),
        title: Text(
          cuenta.header.tipoComprobanteDescripcion ??
              cuenta.header.tipoComprobante,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documento: ${cuenta.header.documentoNumero ?? 'S/N'}',
            ),
            Text(
              'Fecha: ${DateFormat('dd/MM/yyyy').format(cuenta.header.fecha)}',
            ),
            if (cuenta.header.vencimiento != null)
              Text(
                'Vencimiento: ${DateFormat('dd/MM/yyyy').format(cuenta.header.vencimiento!)}',
                style: TextStyle(
                  color: isVencido ? Colors.red : null,
                  fontWeight: isVencido ? FontWeight.bold : null,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${cuenta.header.importe?.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPendiente)
              Text(
                'Pend: \$${cuenta.header.saldoPendiente.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isVencido ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detalle de Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...cuenta.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.concepto} - ${item.conceptoDescripcion ?? ''}',
                            ),
                          ),
                          Text(
                            'x${item.cantidad.toStringAsFixed(0) ?? '1'} = \$${item.importeTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Items:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${cuenta.totalItems.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (cuenta.header.cancelado != null &&
                    cuenta.header.cancelado! > 0)
                  Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cancelado:',
                            style: TextStyle(color: Colors.green),
                          ),
                          Text(
                            '\$${cuenta.header.cancelado!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isPendiente)
                      OutlinedButton.icon(
                        onPressed: () => _showRegistrarPagoDialog(cuenta),
                        icon: const Icon(Icons.payment),
                        label: const Text('Registrar Pago'),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        context.go(
                          '/cuentas-corrientes/${cuenta.header.idtransaccion}',
                        );
                      },
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(cuenta),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRegistrarPagoDialog(CuentaCorrienteCompleta cuenta) async {
    final montoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Saldo pendiente: \$${cuenta.header.saldoPendiente.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: montoController,
                decoration: const InputDecoration(
                  labelText: 'Monto a pagar',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese un monto';
                  }
                  final monto = double.tryParse(value);
                  if (monto == null || monto <= 0) {
                    return 'Monto inválido';
                  }
                  if (monto > cuenta.header.saldoPendiente) {
                    return 'El monto supera el saldo pendiente';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final monto = double.parse(montoController.text);

              try {
                await ref
                    .read(cuentasCorrientesNotifierProvider.notifier)
                    .registrarPago(
                      cuenta.header.idtransaccion!,
                      monto,
                      widget.socioId,
                    );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pago registrado correctamente'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(CuentaCorrienteCompleta cuenta) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Está seguro que desea eliminar la transacción '
          '${cuenta.header.tipoComprobante} - ${cuenta.header.documentoNumero ?? 'S/N'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(cuentasCorrientesNotifierProvider.notifier)
            .deleteCuentaCorriente(
              cuenta.header.idtransaccion!,
              widget.socioId,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transacción eliminada correctamente'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
