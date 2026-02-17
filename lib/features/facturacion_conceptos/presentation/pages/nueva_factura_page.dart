import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../socios/providers/socios_provider.dart';
import '../../../socios/providers/conceptos_provider.dart';
import '../../../socios/models/socio_model.dart';
import '../../../socios/models/concepto_model.dart';
import '../../../profesionales/providers/profesionales_provider.dart';
import '../../../profesionales/models/profesional_model.dart';
import '../../models/factura_concepto_model.dart';
import '../../providers/facturacion_conceptos_provider.dart';

class NuevaFacturaPage extends ConsumerStatefulWidget {
  final int? socioId;             // Si viene desde ficha del socio
  final int? profesionalId;       // Si viene desde ficha del profesional
  final bool esProfesionalInicial; // Pre-selecciona el toggle

  const NuevaFacturaPage({
    super.key,
    this.socioId,
    this.profesionalId,
    this.esProfesionalInicial = false,
  });

  @override
  ConsumerState<NuevaFacturaPage> createState() => _NuevaFacturaPageState();
}

class _NuevaFacturaPageState extends ConsumerState<NuevaFacturaPage> {
  // Búsqueda de socio o profesional
  final _entidadIdController = TextEditingController();
  final _apellidoController = TextEditingController();
  Socio? _socioSeleccionado;
  ProfesionalModel? _profesionalSeleccionado;
  List<Socio> _sociosEncontrados = [];
  List<ProfesionalModel> _profesionalesEncontrados = [];
  bool _buscandoSocios = false;
  bool _esProfesional = false; // false = socio, true = profesional

  // Datos de la factura
  DateTime _fecha = DateTime.now();
  DateTime? _vencimiento;
  final List<ItemFacturaConcepto> _items = [];

  // Para agregar items
  Concepto? _conceptoSeleccionado;
  final _cantidadController = TextEditingController(text: '1');
  final _precioController = TextEditingController();

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.profesionalId != null) {
      _esProfesional = true;
      _cargarProfesionalPorId(widget.profesionalId!);
    } else if (widget.socioId != null) {
      _esProfesional = false;
      _cargarSocioPorId(widget.socioId!);
    } else {
      // Pre-seleccionar toggle según el módulo de origen
      _esProfesional = widget.esProfesionalInicial;
    }
    // Vencimiento por defecto: 30 días
    _vencimiento = _fecha.add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _entidadIdController.dispose();
    _apellidoController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _cargarSocioPorId(int id) async {
    try {
      final socio = await ref.read(socioByIdProvider(id).future);
      if (socio != null && mounted) {
        setState(() {
          _socioSeleccionado = socio;
          _entidadIdController.text = id.toString();
        });
      }
    } catch (e) {
      // Ignorar
    }
  }

  Future<void> _cargarProfesionalPorId(int id) async {
    try {
      final profesional = await ref.read(profesionalByIdProvider(id).future);
      if (profesional != null && mounted) {
        setState(() {
          _profesionalSeleccionado = profesional;
          _entidadIdController.text = id.toString();
        });
      }
    } catch (e) {
      // Ignorar
    }
  }

  Future<void> _buscarSocios() async {
    final idText = _entidadIdController.text.trim();
    final apellido = _apellidoController.text.trim();

    if (idText.isEmpty && apellido.isEmpty) return;

    setState(() => _buscandoSocios = true);

    try {
      if (_esProfesional) {
        final params = ProfesionalesSearchParams(
          profesionalId: idText.isNotEmpty ? int.tryParse(idText) : null,
          apellido: apellido.isNotEmpty ? apellido : null,
          soloActivos: true,
        );
        final profesionales =
            await ref.read(profesionalesSearchProvider(params).future);
        if (mounted) {
          setState(() {
            _profesionalesEncontrados = profesionales;
            _buscandoSocios = false;
          });
        }
      } else {
        final params = SociosSearchParams(
          socioId: idText.isNotEmpty ? int.tryParse(idText) : null,
          apellido: apellido.isNotEmpty ? apellido : null,
          soloActivos: true,
        );
        final socios = await ref.read(sociosSearchProvider(params).future);
        if (mounted) {
          setState(() {
            _sociosEncontrados = socios;
            _buscandoSocios = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _buscandoSocios = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar: $e')),
        );
      }
    }
  }

  void _seleccionarSocio(Socio socio) {
    setState(() {
      _socioSeleccionado = socio;
      _sociosEncontrados = [];
      _entidadIdController.text = socio.id.toString();
      _apellidoController.clear();
    });
  }

  void _seleccionarProfesional(ProfesionalModel profesional) {
    setState(() {
      _profesionalSeleccionado = profesional;
      _profesionalesEncontrados = [];
      _entidadIdController.text = profesional.id.toString();
      _apellidoController.clear();
    });
  }

  void _limpiarSocio() {
    setState(() {
      _socioSeleccionado = null;
      _profesionalSeleccionado = null;
      _entidadIdController.clear();
      _apellidoController.clear();
      _sociosEncontrados = [];
      _profesionalesEncontrados = [];
    });
  }

  void _agregarItem() {
    if (_conceptoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un concepto')),
      );
      return;
    }

    final cantidad = int.tryParse(_cantidadController.text) ?? 1;
    final precio = double.tryParse(_precioController.text) ?? 0;

    if (precio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un precio válido')),
      );
      return;
    }

    setState(() {
      _items.add(ItemFacturaConcepto(
        concepto: _conceptoSeleccionado!.concepto,
        descripcion: _conceptoSeleccionado!.descripcion,
        cantidad: cantidad,
        precioUnitario: precio,
      ));

      // Limpiar para siguiente item
      _conceptoSeleccionado = null;
      _cantidadController.text = '1';
      _precioController.clear();
    });
  }

  void _eliminarItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  double get _total => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  Future<void> _guardarFactura() async {
    final tieneEntidad = _esProfesional
        ? _profesionalSeleccionado != null
        : _socioSeleccionado != null;

    if (!tieneEntidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Seleccione un ${_esProfesional ? 'profesional' : 'socio'}')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregue al menos un concepto')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final factura = _esProfesional
          ? NuevaFacturaConcepto.paraProfesional(
              profesionalId: _profesionalSeleccionado!.id!,
              profesionalNombre: _profesionalSeleccionado!.nombreCompleto,
              fecha: _fecha,
              vencimiento: _vencimiento,
              items: _items,
            )
          : NuevaFacturaConcepto.paraSocio(
              socioId: _socioSeleccionado!.id!,
              socioNombre: _socioSeleccionado!.nombreCompleto,
              fecha: _fecha,
              vencimiento: _vencimiento,
              items: _items,
            );

      final service = ref.read(facturacionConceptosServiceProvider);
      final resultado = await service.crearFactura(factura);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Factura ${resultado.documentoNumero} creada por \$${resultado.importe.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Preguntar si desea ir a cobrar
        final irACobranza = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Factura Creada'),
            content: Text(
              '¿Desea registrar la cobranza de esta factura?\n\n'
              'Documento: ${resultado.documentoNumero}\n'
              'Importe: \$${resultado.importe.toStringAsFixed(2)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sí, cobrar'),
              ),
            ],
          ),
        );

        if (irACobranza == true && mounted) {
          if (_esProfesional) {
            context.go('/cobranzas-profesionales/${_profesionalSeleccionado!.id}');
          } else {
            context.go('/cobranzas/${_socioSeleccionado!.id}');
          }
        } else if (mounted) {
          // Limpiar para nueva factura
          setState(() {
            _items.clear();
            if (widget.socioId == null && widget.profesionalId == null) {
              _socioSeleccionado = null;
              _profesionalSeleccionado = null;
              _entidadIdController.clear();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear factura: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conceptosAsync = ref.watch(conceptosActivosProvider);
    final entidadSeleccionada =
        _esProfesional ? _profesionalSeleccionado != null : _socioSeleccionado != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Factura de Conceptos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/facturacion-conceptos'),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel izquierdo: Formulario
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sección: Socio / Profesional
                  _buildSocioSection(),

                  // Sección: Datos factura (solo si hay entidad seleccionada)
                  if (entidadSeleccionada) ...[
                    const SizedBox(height: 24),
                    _buildDatosFacturaSection(),
                    const SizedBox(height: 24),

                    // Sección: Agregar conceptos
                    conceptosAsync.when(
                      data: (conceptos) =>
                          _buildAgregarConceptoSection(conceptos),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Error cargando conceptos: $e'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Panel derecho: Items y total
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue,
                    child: const Row(
                      children: [
                        Icon(Icons.receipt, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Detalle de Factura',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista de items
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(
                            child: Text(
                              'Agregue conceptos a la factura',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    item.descripcion ?? item.concepto,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(2)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '\$${item.subtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _eliminarItem(index),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Total y botón guardar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL:',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${_total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _guardando ||
                                    _items.isEmpty ||
                                    (_esProfesional
                                        ? _profesionalSeleccionado == null
                                        : _socioSeleccionado == null)
                                ? null
                                : _guardarFactura,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                                _guardando ? 'Guardando...' : 'Crear Factura'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocioSection() {
    final entidadSeleccionada =
        _esProfesional ? _profesionalSeleccionado : _socioSeleccionado;
    final label = _esProfesional ? 'Profesional' : 'Socio';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Toggle socio / profesional (solo si no viene fijo)
                if (widget.socioId == null && widget.profesionalId == null)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Socio')),
                      ButtonSegment(
                          value: true, label: Text('Profesional')),
                    ],
                    selected: {_esProfesional},
                    onSelectionChanged: (val) {
                      setState(() {
                        _esProfesional = val.first;
                        _limpiarSocio();
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (entidadSeleccionada != null) ...[
              // Mostrar entidad seleccionada
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text(
                        _esProfesional
                            ? _profesionalSeleccionado!.apellido[0]
                                .toUpperCase()
                            : _socioSeleccionado!.apellido[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _esProfesional
                                ? _profesionalSeleccionado!.nombreCompleto
                                : _socioSeleccionado!.nombreCompleto,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _esProfesional
                                ? 'ID: ${_profesionalSeleccionado!.id} | Profesional'
                                : 'ID: ${_socioSeleccionado!.id} | Grupo: ${_socioSeleccionado!.grupo ?? "N/A"}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    if (widget.socioId == null && widget.profesionalId == null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _limpiarSocio,
                      ),
                  ],
                ),
              ),
            ] else ...[
              // Buscador
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _entidadIdController,
                      decoration: InputDecoration(
                        labelText: 'ID $label',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _buscarSocios(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _apellidoController,
                      decoration: const InputDecoration(
                        labelText: 'Apellido',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _buscarSocios(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _buscandoSocios ? null : _buscarSocios,
                    icon: _buscandoSocios
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Buscar'),
                  ),
                ],
              ),

              // Resultados socios
              if (_sociosEncontrados.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sociosEncontrados.length,
                    itemBuilder: (context, index) {
                      final socio = _sociosEncontrados[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(socio.apellido[0].toUpperCase()),
                        ),
                        title: Text(socio.nombreCompleto),
                        subtitle: Text(
                            'ID: ${socio.id} | Grupo: ${socio.grupo ?? "N/A"}'),
                        onTap: () => _seleccionarSocio(socio),
                      );
                    },
                  ),
                ),
              ],

              // Resultados profesionales
              if (_profesionalesEncontrados.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _profesionalesEncontrados.length,
                    itemBuilder: (context, index) {
                      final profesional = _profesionalesEncontrados[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          child:
                              Text(profesional.apellido[0].toUpperCase()),
                        ),
                        title: Text(profesional.nombreCompleto),
                        subtitle: Text(
                            'ID: ${profesional.id} | DNI: ${profesional.numeroDocumento ?? "N/A"}'),
                        onTap: () => _seleccionarProfesional(profesional),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatosFacturaSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Datos de la Factura',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _fecha,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() => _fecha = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _vencimiento ??
                            _fecha.add(const Duration(days: 30)),
                        firstDate: _fecha,
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() => _vencimiento = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Vencimiento',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event),
                      ),
                      child: Text(
                        _vencimiento != null
                            ? DateFormat('dd/MM/yyyy').format(_vencimiento!)
                            : 'Seleccionar',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgregarConceptoSection(List<Concepto> conceptos) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.add_shopping_cart, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Agregar Concepto',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<Concepto>(
                    initialValue: _conceptoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Concepto',
                      border: OutlineInputBorder(),
                    ),
                    items: conceptos
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                  '${c.concepto} - ${c.descripcion ?? ""}'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _conceptoSeleccionado = value;
                        // Autocompletar precio si el concepto tiene uno configurado
                        if (value?.importe != null && value!.importe! > 0) {
                          _precioController.text =
                              value.importe!.toStringAsFixed(2);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _cantidadController,
                    decoration: const InputDecoration(
                      labelText: 'Cant.',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _precioController,
                    decoration: const InputDecoration(
                      labelText: 'Precio',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _agregarItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
