import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/cuentas_corrientes_provider.dart';
import '../../providers/entidades_provider.dart';
import '../../providers/tipos_comprobante_provider.dart';
import '../../models/cuenta_corriente_completa_model.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class CuentasCorrientesListPage extends ConsumerStatefulWidget {
  const CuentasCorrientesListPage({super.key});

  @override
  ConsumerState<CuentasCorrientesListPage> createState() =>
      _CuentasCorrientesListPageState();
}

class _CuentasCorrientesListPageState
    extends ConsumerState<CuentasCorrientesListPage> {
  final _documentoController = TextEditingController();
  int? _selectedEntidadId;
  String? _selectedTipoComprobante;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  bool _soloPendientes = false;
  CuentasCorrientesSearchParams? _currentSearch;

  @override
  void dispose() {
    _documentoController.dispose();
    super.dispose();
  }

  void _performSearch() {
    setState(() {
      _currentSearch = CuentasCorrientesSearchParams(
        entidadId: _selectedEntidadId,
        tipoComprobante: _selectedTipoComprobante,
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        soloPendientes: _soloPendientes,
      );
    });
  }

  void _clearSearch() {
    setState(() {
      _documentoController.clear();
      _selectedEntidadId = null;
      _selectedTipoComprobante = null;
      _fechaDesde = null;
      _fechaHasta = null;
      _soloPendientes = false;
      _currentSearch = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entidadesAsync = ref.watch(entidadesProvider);
    final tiposComprobanteAsync = ref.watch(tiposComprobanteProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas Corrientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/cuentas-corrientes'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/cuentas-corrientes/nueva'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Transacción'),
      ),
      body: Column(
        children: [
          // Formulario de búsqueda
          _buildSearchForm(entidadesAsync, tiposComprobanteAsync),

          const Divider(height: 1),

          // Resultados
          Expanded(
            child: _currentSearch == null
                ? _buildEmptyState()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchForm(
    AsyncValue<List> entidadesAsync,
    AsyncValue<List> tiposComprobanteAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Búsqueda de Transacciones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Primera fila: Entidad, Tipo Comprobante
              Row(
                children: [
                  Expanded(
                    child: entidadesAsync.when(
                      data: (entidades) => DropdownButtonFormField<int>(
                        initialValue: _selectedEntidadId,
                        decoration: const InputDecoration(
                          labelText: 'Entidad',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todas'),
                          ),
                          ...entidades.map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.descripcion),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedEntidadId = value);
                        },
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Error cargando entidades'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: tiposComprobanteAsync.when(
                      data: (tipos) => DropdownButtonFormField<String>(
                        initialValue: _selectedTipoComprobante,
                        decoration: const InputDecoration(
                          labelText: 'Tipo Comprobante',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.receipt),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...tipos.map((t) => DropdownMenuItem(
                                value: t.comprobante,
                                child: Text('${t.comprobante} - ${t.descripcion}'),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedTipoComprobante = value);
                        },
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Error cargando tipos'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Segunda fila: Fechas
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _fechaDesde ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _fechaDesde = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha Desde',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _fechaDesde != null
                              ? DateFormat('dd/MM/yyyy').format(_fechaDesde!)
                              : 'Seleccionar',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _fechaHasta ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _fechaHasta = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha Hasta',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _fechaHasta != null
                              ? DateFormat('dd/MM/yyyy').format(_fechaHasta!)
                              : 'Seleccionar',
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Checkbox solo pendientes + botones
              Row(
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
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Utilice los filtros de arriba para buscar transacciones',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final cuentasAsync = ref.watch(
      cuentasCorrientesSearchProvider(_currentSearch!),
    );

    return cuentasAsync.when(
      data: (cuentas) {
        if (cuentas.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No se encontraron transacciones'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cuentas.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${cuentas.length} transacción(es) encontrada(s)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            final cuenta = cuentas[index - 1];
            return _buildCuentaCard(cuenta);
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
          ],
        ),
      ),
    );
  }

  Widget _buildCuentaCard(CuentaCorrienteCompleta cuenta) {
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
          '${cuenta.header.tipoComprobante} - ${cuenta.header.documentoNumero ?? 'S/N'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Socio: ${cuenta.header.socioNombre ?? 'Desconocido'}'),
            Text('Fecha: ${DateFormat('dd/MM/yyyy').format(cuenta.header.fecha)}'),
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
                'Pendiente: \$${cuenta.header.saldoPendiente.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isVencido ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        children: [
          // Detalle de items
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
                            '\$${item.importeTotal.toStringAsFixed(2)}',
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
                      'Total:',
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
                const SizedBox(height: 16),
                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // TODO: Descomentar cuando se implemente registrar pago para todos
                    // if (isPendiente)
                    //   OutlinedButton.icon(
                    //     onPressed: () => _showRegistrarPagoDialog(cuenta),
                    //     icon: const Icon(Icons.payment),
                    //     label: const Text('Registrar Pago'),
                    //   ),
                    // const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        context.go(
                          '/cuentas-corrientes/${cuenta.header.idtransaccion}',
                        );
                      },
                      tooltip: 'Editar',
                    ),
                    if (ref.read(userRoleProvider).esAdministrador)
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
                      cuenta.header.socioId,
                    );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pago registrado correctamente')),
                  );
                  _performSearch();  // Refrescar
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
              cuenta.header.socioId,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transacción eliminada correctamente')),
          );
          _performSearch();  // Refrescar
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
