import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/comprobante_cli_model.dart';
import '../../providers/comprobantes_cli_provider.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../clientes/models/cliente_model.dart';
import '../../../asientos/presentation/widgets/cuentas_search_dialog.dart';
import '../../../cuentas/models/cuenta_model.dart';
import '../../../cuentas/providers/cuentas_provider.dart';
import '../../../../core/utils/date_picker_utils.dart';

class ComprobanteCliFormPage extends ConsumerStatefulWidget {
  final int? idTransaccion;
  final int? clienteId;

  const ComprobanteCliFormPage({
    super.key,
    this.idTransaccion,
    this.clienteId,
  });

  @override
  ConsumerState<ComprobanteCliFormPage> createState() =>
      _ComprobanteCliFormPageState();
}

class _ComprobanteCliFormPageState
    extends ConsumerState<ComprobanteCliFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;
  VenCliHeader? _comprobante;

  // Controllers para header
  final _clienteController = TextEditingController();
  final _nroComprobanteController = TextEditingController();
  final _descripcionController = TextEditingController();

  // Valores del header
  DateTime _fecha = DateTime.now();
  DateTime _fechaReal = DateTime.now();
  DateTime? _fecha1Venc;
  DateTime? _fecha2Venc;
  int? _tipoComprobante;
  String? _tipoFactura;

  // Items
  List<VenCliItem> _items = [];
  int? _cuentaCliente;

  // Validación de sponsor
  Cliente? _clienteSeleccionado;
  bool _buscandoCliente = false;
  bool _clienteValidado = false;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  bool get isEditing => widget.idTransaccion != null;

  @override
  void initState() {
    super.initState();
    _clienteController.addListener(_onClienteCodigoChanged);
    if (isEditing) {
      _loadComprobante();
    } else {
      if (widget.clienteId != null) {
        _clienteController.text = widget.clienteId.toString();
        Future.microtask(
            () => _validarYCargarCliente(widget.clienteId.toString()));
      }
      _isLoadingData = false;
    }
  }

  @override
  void dispose() {
    _clienteController.removeListener(_onClienteCodigoChanged);
    _clienteController.dispose();
    _nroComprobanteController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _onClienteCodigoChanged() {
    final codigoActual = _clienteController.text.trim();
    if (_clienteSeleccionado != null &&
        codigoActual != _clienteSeleccionado!.codigo.toString()) {
      setState(() {
        _clienteSeleccionado = null;
        _clienteValidado = false;
        _cuentaCliente = null;
      });
    }
  }

  Future<void> _validarYCargarCliente(String codigo) async {
    final parsedCodigo = int.tryParse(codigo.trim());
    if (parsedCodigo == null) {
      if (mounted && codigo.trim().isNotEmpty) {
        setState(() {
          _clienteSeleccionado = null;
          _clienteValidado = true;
          _buscandoCliente = false;
          _cuentaCliente = null;
        });
      }
      return;
    }

    if (mounted) setState(() => _buscandoCliente = true);

    try {
      final cliente = await ref.read(clienteProvider(parsedCodigo).future);
      if (mounted) {
        setState(() {
          _clienteSeleccionado = cliente;
          _cuentaCliente = cliente?.cuenta;
          _buscandoCliente = false;
          _clienteValidado = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _clienteSeleccionado = null;
          _buscandoCliente = false;
          _clienteValidado = true;
          _cuentaCliente = null;
        });
      }
    }
  }

  Future<void> _loadComprobante() async {
    try {
      final comprobante =
          await ref.read(comprobanteCliProvider(widget.idTransaccion!).future);

      Cliente? cliente;
      if (comprobante != null) {
        cliente = await ref.read(clienteProvider(comprobante.cliente).future);
      }

      if (comprobante != null && mounted) {
        setState(() {
          _comprobante = comprobante;
          _clienteController.text = comprobante.cliente.toString();
          _clienteSeleccionado = cliente;
          _clienteValidado = true;
          _cuentaCliente = cliente?.cuenta;
          _nroComprobanteController.text = comprobante.nroComprobante ?? '';
          _descripcionController.text = comprobante.descripcionImporte ?? '';
          _fecha = comprobante.fecha;
          _fechaReal = comprobante.fechaReal;
          _fecha1Venc = comprobante.fecha1Venc;
          _fecha2Venc = comprobante.fecha2Venc;
          _tipoComprobante = comprobante.tipoComprobante;
          _tipoFactura = comprobante.tipoFactura;
          _items = comprobante.items ?? [];
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando comprobante: $e')),
        );
      }
    }
  }

  int _getAnioMes(DateTime fecha) {
    return fecha.year * 100 + fecha.month;
  }

  double _calcularTotal() {
    return _items.fold(0, (sum, item) => sum + item.importe);
  }

  /// Si contiene guión: "1-10" → "0001-00000010".
  /// Sin guión: guarda tal cual (hasta 14 chars). Retorna null si vacío.
  String? _formatNroComprobante(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('-')) return trimmed;
    final parts = trimmed.split('-');
    if (parts.length != 2) return trimmed;
    final p1 = int.tryParse(parts[0]);
    final p2 = int.tryParse(parts[1]);
    if (p1 == null || p2 == null) return trimmed;
    return '${p1.toString().padLeft(4, '0')}-${p2.toString().padLeft(8, '0')}';
  }

  Future<void> _saveComprobante() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tipoComprobante == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debe seleccionar un tipo de comprobante')),
      );
      return;
    }

    final clienteId = int.tryParse(_clienteController.text.trim());
    if (clienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de sponsor inválido')),
      );
      return;
    }

    if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sponsor no encontrado. Verifique el código.')),
      );
      return;
    }

    // Validar que todas las cuentas contables de los items existan
    final cuentasAsync = ref.read(cuentasProvider);
    final cuentas = cuentasAsync.asData?.value;
    if (cuentas != null) {
      final cuentasValidas = cuentas.map((c) => c.cuenta).toSet();
      final cuentasInvalidas = _items
          .where((i) => i.cuenta != 0 && !cuentasValidas.contains(i.cuenta))
          .map((i) => i.cuenta)
          .toSet();
      if (cuentasInvalidas.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Las siguientes cuentas contables no existen: ${cuentasInvalidas.join(', ')}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final header = VenCliHeader(
        idTransaccion: _comprobante?.idTransaccion,
        comprobante: _comprobante?.comprobante ?? 0,
        anioMes: _getAnioMes(_fecha),
        fecha: _fecha,
        cliente: clienteId,
        tipoComprobante: _tipoComprobante!,
        nroComprobante: _formatNroComprobante(_nroComprobanteController.text),
        tipoFactura: _tipoFactura,
        totalImporte: _calcularTotal(),
        cancelado: _comprobante?.cancelado ?? 0,
        fecha1Venc: _fecha1Venc,
        fecha2Venc: _fecha2Venc,
        estado: 'P', // Estado siempre es P (Pendiente)
        fechaReal: _fechaReal,
        descripcionImporte: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
      );

      final notifier = ref.read(comprobantesCliNotifierProvider.notifier);

      if (isEditing) {
        await notifier.actualizarComprobante(header, _items);
      } else {
        await notifier.crearComprobante(header, _items);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Comprobante actualizado correctamente'
                : 'Comprobante creado correctamente'),
          ),
        );
        context.go('/comprobantes-clientes');
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        if (errorStr.contains('ASIENTO_WARNING:')) {
          final warning = errorStr
              .split('ASIENTO_WARNING:')
              .last
              .replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Comprobante guardado. Advertencia en asiento contable: $warning',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 8),
            ),
          );
          context.go('/comprobantes-clientes');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorStr'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectFecha(String tipo) async {
    DateTime initialDate;
    switch (tipo) {
      case 'fecha':
        initialDate = _fecha;
        break;
      case 'fechaReal':
        initialDate = _fechaReal;
        break;
      case 'fecha1Venc':
        initialDate = _fecha1Venc ?? DateTime.now();
        break;
      case 'fecha2Venc':
        initialDate = _fecha2Venc ?? DateTime.now();
        break;
      default:
        return;
    }

    final fecha = await pickDate(context, initialDate);

    if (fecha != null) {
      setState(() {
        switch (tipo) {
          case 'fecha':
            _fecha = fecha;
            break;
          case 'fechaReal':
            _fechaReal = fecha;
            break;
          case 'fecha1Venc':
            _fecha1Venc = fecha;
            break;
          case 'fecha2Venc':
            _fecha2Venc = fecha;
            break;
        }
      });
    }
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _ItemDialog(
        tipoComprobante: _tipoComprobante,
        cuentaCliente: _cuentaCliente,
        onSave: (item) {
          setState(() {
            _items.add(item);
          });
        },
      ),
    );
  }

  void _editItem(int index) {
    showDialog(
      context: context,
      builder: (context) => _ItemDialog(
        item: _items[index],
        tipoComprobante: _tipoComprobante,
        cuentaCliente: _cuentaCliente,
        onSave: (item) {
          setState(() {
            _items[index] = item;
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _buscarCliente() async {
    final result = await showDialog<Cliente>(
      context: context,
      builder: (context) => const _ClienteSearchDialog(),
    );

    if (result != null) {
      setState(() {
        _clienteController.text = result.codigo.toString();
        _clienteSeleccionado = result;
        _cuentaCliente = result.cuenta;
        _clienteValidado = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiposAsync = ref.watch(tiposComprobanteVentaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Comprobante' : 'Nuevo Comprobante'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/comprobantes-clientes'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Datos del comprobante
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Datos del Comprobante',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _clienteController,
                                        decoration: InputDecoration(
                                          labelText: 'Código Sponsor *',
                                          border: const OutlineInputBorder(),
                                          prefixIcon:
                                              const Icon(Icons.business),
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_buscandoCliente)
                                                const Padding(
                                                  padding: EdgeInsets.all(12),
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2),
                                                  ),
                                                ),
                                              IconButton(
                                                icon: const Icon(Icons.search),
                                                tooltip: 'Buscar sponsor',
                                                onPressed: _buscarCliente,
                                              ),
                                            ],
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onFieldSubmitted:
                                            _validarYCargarCliente,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Ingrese el código del sponsor';
                                          }
                                          if (int.tryParse(value.trim()) ==
                                              null) {
                                            return 'Código inválido';
                                          }
                                          return null;
                                        },
                                      ),
                                      if (_clienteSeleccionado != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 16),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  _clienteSeleccionado!
                                                      .nombreCompleto,
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (_clienteValidado &&
                                          _clienteController.text
                                              .trim()
                                              .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Row(
                                            children: [
                                              Icon(Icons.error_outline,
                                                  color: Colors.red[700],
                                                  size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Sponsor no encontrado',
                                                style: TextStyle(
                                                  color: Colors.red[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: tiposAsync.when(
                                    data: (tipos) =>
                                        DropdownButtonFormField<int?>(
                                      initialValue: _tipoComprobante,
                                      decoration: const InputDecoration(
                                        labelText: 'Tipo Comprobante *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.category),
                                      ),
                                      items: tipos
                                          .map((tipo) => DropdownMenuItem<int?>(
                                                value: tipo.codigo,
                                                child: Text(tipo.descripcion),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _tipoComprobante = value;
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null) {
                                          return 'Seleccione tipo';
                                        }
                                        return null;
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
                                        labelText: 'Error',
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
                                  child: TextFormField(
                                    controller: _nroComprobanteController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nro. Comprobante',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.receipt),
                                      hintText: 'XXXX-XXXXXXXX',
                                    ),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    initialValue: _tipoFactura,
                                    decoration: const InputDecoration(
                                      labelText: 'Tipo Factura',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.description),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: null, child: Text('--')),
                                      DropdownMenuItem(
                                          value: 'A', child: Text('A')),
                                      DropdownMenuItem(
                                          value: 'B', child: Text('B')),
                                      DropdownMenuItem(
                                          value: 'C', child: Text('C')),
                                      DropdownMenuItem(
                                          value: 'M', child: Text('M')),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _tipoFactura = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fechas
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fechas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectFecha('fecha'),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Fecha Comprobante *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.calendar_today),
                                      ),
                                      child: Text(_dateFormat.format(_fecha)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectFecha('fechaReal'),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Fecha Contable *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.calendar_month),
                                      ),
                                      child:
                                          Text(_dateFormat.format(_fechaReal)),
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
                                    onTap: () => _selectFecha('fecha1Venc'),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: '1er Vencimiento',
                                        border: const OutlineInputBorder(),
                                        prefixIcon:
                                            const Icon(Icons.event_available),
                                        suffixIcon: _fecha1Venc != null
                                            ? IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  setState(() {
                                                    _fecha1Venc = null;
                                                  });
                                                },
                                              )
                                            : null,
                                      ),
                                      child: Text(_fecha1Venc != null
                                          ? _dateFormat.format(_fecha1Venc!)
                                          : ''),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectFecha('fecha2Venc'),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: '2do Vencimiento',
                                        border: const OutlineInputBorder(),
                                        prefixIcon:
                                            const Icon(Icons.event_busy),
                                        suffixIcon: _fecha2Venc != null
                                            ? IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  setState(() {
                                                    _fecha2Venc = null;
                                                  });
                                                },
                                              )
                                            : null,
                                      ),
                                      child: Text(_fecha2Venc != null
                                          ? _dateFormat.format(_fecha2Venc!)
                                          : ''),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Descripción',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descripcionController,
                              decoration: const InputDecoration(
                                labelText: 'Descripción / Observaciones',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.notes),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Items',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _addItem,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Agregar Item'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_items.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text(
                                    'No hay items agregados',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _items.length,
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  return Card(
                                    color: Colors.grey[50],
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text('${index + 1}'),
                                      ),
                                      title: Text(
                                        'Concepto: ${item.concepto} - Cuenta: ${item.cuenta}',
                                      ),
                                      subtitle: Text(
                                        'Importe: ${_currencyFormat.format(item.importe)} | Alícuota: ${item.alicuota}%',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () => _editItem(index),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () => _removeItem(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Total: ${_currencyFormat.format(_calcularTotal())}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => context.go('/comprobantes-clientes'),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _saveComprobante,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(isEditing ? 'Actualizar' : 'Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Diálogo para agregar/editar items
class _ItemDialog extends ConsumerStatefulWidget {
  final VenCliItem? item;
  final int? tipoComprobante;
  final int? cuentaCliente;
  final Function(VenCliItem) onSave;

  const _ItemDialog({
    this.item,
    this.tipoComprobante,
    this.cuentaCliente,
    required this.onSave,
  });

  @override
  ConsumerState<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<_ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cuentaController = TextEditingController();
  final _importeController = TextEditingController();
  final _baseContableController = TextEditingController();
  final _alicuotaController = TextEditingController();
  final _detalleController = TextEditingController();

  String? _selectedConcepto;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _selectedConcepto = widget.item!.concepto.trim();
      _cuentaController.text = widget.item!.cuenta.toString();
      _importeController.text = widget.item!.importe.toString();
      _baseContableController.text = widget.item!.baseContable.toString();
      _alicuotaController.text = widget.item!.alicuota.toString();
      _detalleController.text = widget.item!.detalle ?? '';
    } else {
      _baseContableController.text = '0';
      _alicuotaController.text = '0';
      if (widget.cuentaCliente != null) {
        _cuentaController.text = widget.cuentaCliente.toString();
      }
    }
  }

  @override
  void dispose() {
    _cuentaController.dispose();
    _importeController.dispose();
    _baseContableController.dispose();
    _alicuotaController.dispose();
    _detalleController.dispose();
    super.dispose();
  }

  Future<void> _buscarCuenta() async {
    final result = await showDialog<Cuenta>(
      context: context,
      builder: (context) => const CuentasSearchDialog(),
    );
    if (result != null) {
      setState(() {
        _cuentaController.text = result.cuenta.toString();
      });
    }
  }

  Widget _buildConceptoField(List<String> conceptos) {
    if (conceptos.isNotEmpty) {
      final valorValido =
          _selectedConcepto != null && conceptos.contains(_selectedConcepto);

      return DropdownButtonFormField<String>(
        initialValue: valorValido ? _selectedConcepto : null,
        decoration: const InputDecoration(
          labelText: 'Concepto *',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.category),
        ),
        items: conceptos
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (value) => setState(() => _selectedConcepto = value),
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? 'Requerido' : null,
      );
    }

    // Fallback: campo de texto libre, con 'EXE' como sugerencia por defecto
    _selectedConcepto ??= 'EXE';
    return TextFormField(
      initialValue: _selectedConcepto,
      decoration: InputDecoration(
        labelText: 'Concepto *',
        border: const OutlineInputBorder(),
        helperText: widget.tipoComprobante == null
            ? 'Seleccione el tipo de comprobante primero'
            : 'Sin conceptos configurados para este tipo',
      ),
      maxLength: 5,
      textCapitalization: TextCapitalization.characters,
      onChanged: (value) => _selectedConcepto = value.trim().toUpperCase(),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Requerido' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conceptosAsync = widget.tipoComprobante != null
        ? ref.watch(conceptosPorTipoCliProvider(widget.tipoComprobante!))
        : const AsyncValue<List<String>>.data([]);

    return AlertDialog(
      title: Text(widget.item != null ? 'Editar Item' : 'Agregar Item'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                conceptosAsync.when(
                  data: _buildConceptoField,
                  loading: () => const TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Cargando conceptos...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  error: (_, __) => _buildConceptoField([]),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _importeController,
                        decoration: const InputDecoration(
                          labelText: 'Importe *',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requerido';
                          }
                          if (double.tryParse(value.trim()) == null) {
                            return 'Número inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _alicuotaController,
                        decoration: const InputDecoration(
                          labelText: 'Alícuota',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _baseContableController,
                  decoration: const InputDecoration(
                    labelText: 'Base Contable',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _detalleController,
                  decoration: const InputDecoration(
                    labelText: 'Detalle',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final item = VenCliItem(
                idCampo: widget.item?.idCampo,
                idTransaccion: widget.item?.idTransaccion,
                comprobante: widget.item?.comprobante ?? 0,
                anioMes: widget.item?.anioMes ?? 0,
                item: widget.item?.item ?? 0,
                concepto: (_selectedConcepto ?? '').toUpperCase(),
                cuenta: int.parse(_cuentaController.text.trim()),
                importe: double.parse(_importeController.text.trim()),
                baseContable:
                    double.tryParse(_baseContableController.text.trim()) ?? 0,
                alicuota: double.tryParse(_alicuotaController.text.trim()) ?? 0,
                detalle: _detalleController.text.trim().isEmpty
                    ? null
                    : _detalleController.text.trim(),
              );
              widget.onSave(item);
              Navigator.pop(context);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// Diálogo para buscar clientes/sponsors
class _ClienteSearchDialog extends ConsumerStatefulWidget {
  const _ClienteSearchDialog();

  @override
  ConsumerState<_ClienteSearchDialog> createState() =>
      _ClienteSearchDialogState();
}

class _ClienteSearchDialogState extends ConsumerState<_ClienteSearchDialog> {
  final _searchController = TextEditingController();
  List<Cliente> _resultados = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final params = ClientesSearchParams(
        razonSocial: query,
        soloActivos: true,
      );
      final clientes = await ref.read(clientesSearchProvider(params).future);

      if (mounted) {
        setState(() {
          _resultados = clientes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.business, color: Colors.green),
          SizedBox(width: 8),
          Text('Buscar Sponsor'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Razón Social',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _buscar,
                ),
              ),
              onSubmitted: (_) => _buscar(),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: !_hasSearched
                  ? const Center(
                      child: Text(
                        'Ingrese un texto para buscar',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _resultados.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron clientes',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _resultados.length,
                              itemBuilder: (context, index) {
                                final cliente = _resultados[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green,
                                    child: Text(
                                      cliente.codigo.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(cliente.nombreCompleto),
                                  subtitle: cliente.cuit?.isNotEmpty == true
                                      ? Text('CUIT: ${cliente.cuit}')
                                      : null,
                                  onTap: () => Navigator.pop(context, cliente),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
