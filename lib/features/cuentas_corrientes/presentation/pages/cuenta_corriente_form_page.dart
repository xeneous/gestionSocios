import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/cuenta_corriente_model.dart';
import '../../models/detalle_cuenta_corriente_model.dart';
import '../../models/cuenta_corriente_completa_model.dart';
import '../../providers/cuentas_corrientes_provider.dart';
import '../../providers/entidades_provider.dart';
import '../../providers/tipos_comprobante_provider.dart';
import '../../../socios/models/socio_model.dart';
import '../../../socios/providers/socios_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/detalle_item_row.dart';

class CuentaCorrienteFormPage extends ConsumerStatefulWidget {
  final int? idtransaccion;

  const CuentaCorrienteFormPage({super.key, this.idtransaccion});

  @override
  ConsumerState<CuentaCorrienteFormPage> createState() =>
      _CuentaCorrienteFormPageState();
}

class _CuentaCorrienteFormPageState
    extends ConsumerState<CuentaCorrienteFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Header fields
  Socio? _selectedSocio;
  int? _selectedEntidadId;
  String? _selectedTipoComprobante;
  DateTime _fecha = DateTime.now();
  final _puntoVentaController = TextEditingController();
  final _documentoNumeroController = TextEditingController();
  DateTime? _fechaRendicion;
  final _rendicionController = TextEditingController();
  DateTime? _vencimiento;

  // Items
  List<DetalleItemRowData> _items = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.idtransaccion != null) {
      _loadCuentaCorrienteData();
    } else {
      _addNewItem();
    }
  }

  Future<void> _loadCuentaCorrienteData() async {
    setState(() => _isLoading = true);

    try {
      final cuenta = await ref
          .read(cuentasCorrientesNotifierProvider.notifier)
          .getCuentaCorrienteById(widget.idtransaccion!);

      if (cuenta != null && mounted) {
        // Cargar socio
        final socio = await ref
            .read(sociosNotifierProvider.notifier)
            .getSocioById(cuenta.header.socioId);

        setState(() {
          _selectedSocio = socio;
          _selectedEntidadId = cuenta.header.entidadId;
          _selectedTipoComprobante = cuenta.header.tipoComprobante;
          _fecha = cuenta.header.fecha;
          _puntoVentaController.text = cuenta.header.puntoVenta ?? '';
          _documentoNumeroController.text = cuenta.header.documentoNumero ?? '';
          _fechaRendicion = cuenta.header.fechaRendicion;
          _rendicionController.text = cuenta.header.rendicion ?? '';
          _vencimiento = cuenta.header.vencimiento;

          // Cargar items
          _items = cuenta.items.map((item) {
            return DetalleItemRowData(
              concepto: item.concepto,
              conceptoDescripcion: item.conceptoDescripcion,
              cantidad: item.cantidad,
              importe: item.importe,
            );
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _puntoVentaController.dispose();
    _documentoNumeroController.dispose();
    _rendicionController.dispose();
    super.dispose();
  }

  void _addNewItem() {
    setState(() {
      _items.add(DetalleItemRowData());
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  double get _totalItems {
    return _items.fold(0.0, (sum, item) => sum + item.importeTotal);
  }

  Future<void> _saveCuentaCorriente() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor complete todos los campos requeridos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedSocio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un socio'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_items.isEmpty || _items.any((i) => i.concepto == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agregue al menos un item de detalle válido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final header = CuentaCorriente(
        idtransaccion: widget.idtransaccion,
        socioId: _selectedSocio!.id!,
        entidadId: _selectedEntidadId!,
        fecha: _fecha,
        tipoComprobante: _selectedTipoComprobante!,
        puntoVenta: _puntoVentaController.text.isEmpty
            ? null
            : _puntoVentaController.text,
        documentoNumero: _documentoNumeroController.text.isEmpty
            ? null
            : _documentoNumeroController.text,
        fechaRendicion: _fechaRendicion,
        rendicion: _rendicionController.text.isEmpty
            ? null
            : _rendicionController.text,
        importe: _totalItems,
        cancelado: 0.0,
        vencimiento: _vencimiento,
      );

      final items = _items.asMap().entries.map((entry) {
        final item = entry.value;
        return DetalleCuentaCorriente(
          idtransaccion: widget.idtransaccion ?? 0,  // Se reemplazará en el provider
          item: entry.key + 1,
          concepto: item.concepto!,
          cantidad: item.cantidad,
          importe: item.importe,
        );
      }).toList();

      final cuentaCompleta = CuentaCorrienteCompleta(
        header: header,
        items: items,
      );

      if (widget.idtransaccion != null) {
        await ref
            .read(cuentasCorrientesNotifierProvider.notifier)
            .updateCuentaCorriente(widget.idtransaccion!, cuentaCompleta);
      } else {
        await ref
            .read(cuentasCorrientesNotifierProvider.notifier)
            .createCuentaCorriente(cuentaCompleta);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.idtransaccion != null
                  ? 'Cuenta corriente actualizada'
                  : 'Cuenta corriente creada',
            ),
          ),
        );
        context.go('/cuentas-corrientes');
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entidadesAsync = ref.watch(entidadesProvider);
    final tiposComprobanteAsync = ref.watch(tiposComprobanteProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.idtransaccion != null
              ? 'Editar Cuenta Corriente'
              : 'Nueva Cuenta Corriente',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // HEADER SECTION
                        const Text(
                          'Datos de la Transacción',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Socio
                        _buildSocioSelector(),
                        const SizedBox(height: 16),

                        // Entidad + Tipo Comprobante
                        Row(
                          children: [
                            Expanded(
                              child: entidadesAsync.when(
                                data: (entidades) =>
                                    DropdownButtonFormField<int>(
                                  initialValue: _selectedEntidadId,
                                  decoration: const InputDecoration(
                                    labelText: 'Entidad *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: entidades
                                      .map((e) => DropdownMenuItem(
                                            value: e.id,
                                            child: Text(e.descripcion),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedEntidadId = value);
                                  },
                                  validator: (value) => value == null
                                      ? 'Seleccione una entidad'
                                      : null,
                                ),
                                loading: () =>
                                    const CircularProgressIndicator(),
                                error: (_, __) =>
                                    const Text('Error cargando entidades'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: tiposComprobanteAsync.when(
                                data: (tipos) =>
                                    DropdownButtonFormField<String>(
                                  initialValue: _selectedTipoComprobante,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo Comprobante *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: tipos
                                      .map((t) => DropdownMenuItem(
                                            value: t.comprobante,
                                            child: Text(
                                              '${t.comprobante} - ${t.descripcion}',
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(
                                        () => _selectedTipoComprobante = value);
                                  },
                                  validator: (value) => value == null
                                      ? 'Seleccione un tipo'
                                      : null,
                                ),
                                loading: () =>
                                    const CircularProgressIndicator(),
                                error: (_, __) =>
                                    const Text('Error cargando tipos'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Fecha + Punto Venta + Documento
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _fecha,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setState(() => _fecha = date);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Fecha *',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    DateFormat('dd/MM/yyyy').format(_fecha),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _puntoVentaController,
                                decoration: const InputDecoration(
                                  labelText: 'Punto Venta',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _documentoNumeroController,
                                decoration: const InputDecoration(
                                  labelText: 'Nº Documento',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Vencimiento
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _vencimiento ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() => _vencimiento = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Vencimiento',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _vencimiento != null
                                  ? DateFormat('dd/MM/yyyy').format(_vencimiento!)
                                  : 'Seleccionar fecha',
                            ),
                          ),
                        ),

                        const Divider(height: 32),

                        // ITEMS SECTION
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Items del Comprobante',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _addNewItem,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar Item'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Items list
                        ..._items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;

                          return DetalleItemRow(
                            key: ValueKey(index),
                            itemNumber: index + 1,
                            data: item,
                            onRemove: () => _removeItem(index),
                            onChanged: () => setState(() {}),
                          );
                        }),

                        const SizedBox(height: 16),

                        // Total
                        Card(
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL COMPROBANTE:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '\$${_totalItems.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Botones de acción (fixed bottom)
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildSocioSelector() {
    return InkWell(
      onTap: () async {
        final socio = await showDialog<Socio>(
          context: context,
          builder: (context) => const _SocioSearchDialog(),
        );

        if (socio != null) {
          setState(() => _selectedSocio = socio);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Socio *',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.search),
        ),
        child: Text(
          _selectedSocio != null
              ? '${_selectedSocio!.id} - ${_selectedSocio!.nombreCompleto}'
              : 'Buscar socio...',
          style: TextStyle(
            color: _selectedSocio != null ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => context.go('/cuentas-corrientes'),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _saveCuentaCorriente,
            icon: const Icon(Icons.save),
            label: Text(
              widget.idtransaccion != null ? 'Actualizar' : 'Guardar',
            ),
          ),
        ],
      ),
    );
  }
}

// Widget para buscar socios (simplificado - reusar del módulo socios)
class _SocioSearchDialog extends ConsumerStatefulWidget {
  const _SocioSearchDialog();

  @override
  ConsumerState<_SocioSearchDialog> createState() => _SocioSearchDialogState();
}

class _SocioSearchDialogState extends ConsumerState<_SocioSearchDialog> {
  final _searchController = TextEditingController();
  SociosSearchParams _params = SociosSearchParams();

  @override
  Widget build(BuildContext context) {
    final sociosAsync = ref.watch(sociosSearchProvider(_params));

    return AlertDialog(
      title: const Text('Buscar Socio'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Apellido',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                setState(() {
                  _params = SociosSearchParams(
                    apellido: _searchController.text,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: sociosAsync.when(
                data: (socios) => ListView.builder(
                  itemCount: socios.length,
                  itemBuilder: (context, index) {
                    final socio = socios[index];
                    return ListTile(
                      title: Text(socio.nombreCompleto),
                      subtitle: Text('ID: ${socio.id}'),
                      onTap: () => Navigator.pop(context, socio),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
