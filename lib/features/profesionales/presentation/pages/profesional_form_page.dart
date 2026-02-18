import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/profesional_model.dart';
import '../../providers/profesionales_provider.dart';
import '../../../socios/providers/tarjetas_provider.dart';
import '../../../../core/utils/date_picker_utils.dart';

class ProfesionalFormPage extends ConsumerStatefulWidget {
  final int? profesionalId;

  const ProfesionalFormPage({super.key, this.profesionalId});

  @override
  ConsumerState<ProfesionalFormPage> createState() =>
      _ProfesionalFormPageState();
}

class _ProfesionalFormPageState extends ConsumerState<ProfesionalFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Datos Básicos
  final _apellidoController = TextEditingController();
  final _nombreController = TextEditingController();
  final _dniController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _domicilioController = TextEditingController();

  // Débito Automático
  bool _adheridoDebito = false;
  int? _tarjetaId;
  final _numeroTarjetaController = TextEditingController();
  DateTime? _vencimientoTarjeta;
  DateTime? _debitarDesde;

  @override
  void initState() {
    super.initState();
    if (widget.profesionalId != null) {
      _loadProfesional();
    }
  }

  @override
  void dispose() {
    _apellidoController.dispose();
    _nombreController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _domicilioController.dispose();
    _numeroTarjetaController.dispose();
    super.dispose();
  }

  Future<void> _loadProfesional() async {
    setState(() => _isLoading = true);
    try {
      final profesional =
          await ref.read(profesionalByIdProvider(widget.profesionalId!).future);

      if (profesional != null && mounted) {
        setState(() {
          _apellidoController.text = profesional.apellido;
          _nombreController.text = profesional.nombre;
          _dniController.text = profesional.numeroDocumento ?? '';
          _emailController.text = profesional.email ?? '';
          _telefonoController.text = profesional.telefono ?? '';
          _domicilioController.text = profesional.domicilio ?? '';

          _adheridoDebito = profesional.adheridoDebito;
          _tarjetaId = profesional.tarjetaId;
          _numeroTarjetaController.text = profesional.numeroTarjeta ?? '';
          _vencimientoTarjeta = profesional.vencimientoTarjeta;
          _debitarDesde = profesional.debitarDesde;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar profesional: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfesional() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profesional = ProfesionalModel(
        id: widget.profesionalId,
        apellido: _apellidoController.text.trim(),
        nombre: _nombreController.text.trim(),
        numeroDocumento: _dniController.text.trim().isNotEmpty
            ? _dniController.text.trim()
            : null,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        telefono: _telefonoController.text.trim().isNotEmpty
            ? _telefonoController.text.trim()
            : null,
        domicilio: _domicilioController.text.trim().isNotEmpty
            ? _domicilioController.text.trim()
            : null,
        adheridoDebito: _adheridoDebito,
        tarjetaId: _adheridoDebito ? _tarjetaId : null,
        numeroTarjeta: _adheridoDebito && _numeroTarjetaController.text.isNotEmpty
            ? _numeroTarjetaController.text.trim()
            : null,
        vencimientoTarjeta: _adheridoDebito ? _vencimientoTarjeta : null,
        debitarDesde: _adheridoDebito ? _debitarDesde : null,
      );

      if (widget.profesionalId == null) {
        // Crear nuevo
        await ref
            .read(profesionalesNotifierProvider.notifier)
            .createProfesional(profesional);
      } else {
        // Actualizar existente
        await ref
            .read(profesionalesNotifierProvider.notifier)
            .updateProfesional(profesional);
      }

      ref.invalidate(profesionalesSearchProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.profesionalId == null
                ? 'Profesional creado correctamente'
                : 'Profesional actualizado correctamente'),
          ),
        );
        context.go('/profesionales');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
    final tarjetasAsync = ref.watch(tarjetasProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profesionalId == null
            ? 'Nuevo Profesional'
            : 'Editar Profesional'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profesionales'),
        ),
        actions: [
          if (widget.profesionalId != null) ...[
            IconButton(
              icon: const Icon(Icons.account_balance_wallet),
              tooltip: 'Cuenta Corriente',
              onPressed: () => context.go(
                  '/profesionales/${widget.profesionalId}/cuenta-corriente'),
            ),
            IconButton(
              icon: const Icon(Icons.receipt),
              tooltip: 'Facturar Conceptos',
              onPressed: () => context.go(
                  '/facturacion-profesionales/${widget.profesionalId}'),
            ),
            IconButton(
              icon: const Icon(Icons.payments),
              tooltip: 'Cobranzas',
              onPressed: () => context.go(
                  '/cobranzas-profesionales/${widget.profesionalId}'),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Datos Básicos
                      const Text(
                        'Datos Básicos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _apellidoController,
                                      decoration: const InputDecoration(
                                        labelText: 'Apellido *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.person),
                                      ),
                                      textCapitalization: TextCapitalization.words,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'El apellido es requerido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nombreController,
                                      decoration: const InputDecoration(
                                        labelText: 'Nombre *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                      textCapitalization: TextCapitalization.words,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'El nombre es requerido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _dniController,
                                      decoration: const InputDecoration(
                                        labelText: 'DNI',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.credit_card),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _emailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.email),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _telefonoController,
                                      decoration: const InputDecoration(
                                        labelText: 'Teléfono',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.phone),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _domicilioController,
                                      decoration: const InputDecoration(
                                        labelText: 'Domicilio',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.home),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Débito Automático
                      const Text(
                        'Débito Automático',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text('Adherido a Débito Automático'),
                                subtitle: Text(_adheridoDebito
                                    ? 'El profesional está adherido al débito automático'
                                    : 'El profesional no está adherido'),
                                value: _adheridoDebito,
                                onChanged: (value) {
                                  setState(() => _adheridoDebito = value);
                                },
                              ),
                              if (_adheridoDebito) ...[
                                const Divider(),
                                const SizedBox(height: 16),
                                tarjetasAsync.when(
                                  data: (tarjetas) => DropdownButtonFormField<int>(
                                    value: _tarjetaId,
                                    decoration: const InputDecoration(
                                      labelText: 'Tarjeta',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.credit_card),
                                    ),
                                    items: tarjetas.map((tarjeta) {
                                      return DropdownMenuItem(
                                        value: tarjeta.id,
                                        child: Text(tarjeta.descripcion),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() => _tarjetaId = value);
                                    },
                                  ),
                                  loading: () => const LinearProgressIndicator(),
                                  error: (error, _) =>
                                      Text('Error cargando tarjetas: $error'),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _numeroTarjetaController,
                                  decoration: const InputDecoration(
                                    labelText: 'Número de Tarjeta',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.numbers),
                                    hintText: 'Últimos 16 dígitos',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(16),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final date = await pickDate(context, _vencimientoTarjeta ?? DateTime.now());
                                          if (date != null) {
                                            setState(
                                                () => _vencimientoTarjeta = date);
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Vencimiento Tarjeta',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.calendar_today),
                                          ),
                                          child: Text(
                                            _vencimientoTarjeta != null
                                                ? DateFormat('MM/yy')
                                                    .format(_vencimientoTarjeta!)
                                                : 'Seleccionar fecha',
                                            style: TextStyle(
                                              color: _vencimientoTarjeta != null
                                                  ? Colors.black
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final date = await pickDate(context, _debitarDesde ?? DateTime.now());
                                          if (date != null) {
                                            setState(() => _debitarDesde = date);
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Debitar Desde',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.event),
                                          ),
                                          child: Text(
                                            _debitarDesde != null
                                                ? DateFormat('dd/MM/yyyy')
                                                    .format(_debitarDesde!)
                                                : 'Seleccionar fecha',
                                            style: TextStyle(
                                              color: _debitarDesde != null
                                                  ? Colors.black
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Botones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => context.go('/profesionales'),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _saveProfesional,
                            icon: const Icon(Icons.save),
                            label: const Text('Guardar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
