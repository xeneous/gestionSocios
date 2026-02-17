import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/proveedor_model.dart';
import '../../providers/proveedores_provider.dart';
import '../../../asientos/presentation/widgets/cuentas_search_dialog.dart';
import '../../../cuentas/models/cuenta_model.dart';

class ProveedorFormPage extends ConsumerStatefulWidget {
  final int? proveedorId;

  const ProveedorFormPage({super.key, this.proveedorId});

  @override
  ConsumerState<ProveedorFormPage> createState() => _ProveedorFormPageState();
}

class _ProveedorFormPageState extends ConsumerState<ProveedorFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;
  Proveedor? _proveedor;
  bool _activo = true;

  // Controllers
  final _razonSocialController = TextEditingController();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _cuitController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _localidadController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  final _telefono1Controller = TextEditingController();
  final _telefono2Controller = TextEditingController();
  final _mailController = TextEditingController();
  final _notasController = TextEditingController();
  final _cuentaController = TextEditingController();

  bool get isEditing => widget.proveedorId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadProveedor();
    } else {
      _isLoadingData = false;
    }
  }

  @override
  void dispose() {
    _razonSocialController.dispose();
    _nombreController.dispose();
    _apellidoController.dispose();
    _cuitController.dispose();
    _domicilioController.dispose();
    _localidadController.dispose();
    _codigoPostalController.dispose();
    _telefono1Controller.dispose();
    _telefono2Controller.dispose();
    _mailController.dispose();
    _notasController.dispose();
    _cuentaController.dispose();
    super.dispose();
  }

  Future<void> _loadProveedor() async {
    try {
      final proveedor = await ref.read(proveedorProvider(widget.proveedorId!).future);
      if (proveedor != null && mounted) {
        setState(() {
          _proveedor = proveedor;
          _razonSocialController.text = proveedor.razonSocial ?? '';
          _nombreController.text = proveedor.nombre ?? '';
          _apellidoController.text = proveedor.apellido ?? '';
          _cuitController.text = proveedor.cuit ?? '';
          _domicilioController.text = proveedor.domicilio ?? '';
          _localidadController.text = proveedor.localidad ?? '';
          _codigoPostalController.text = proveedor.codigoPostal ?? '';
          _telefono1Controller.text = proveedor.telefono1 ?? '';
          _telefono2Controller.text = proveedor.telefono2 ?? '';
          _mailController.text = proveedor.mail ?? '';
          _notasController.text = proveedor.notas ?? '';
          _cuentaController.text = proveedor.cuenta?.toString() ?? '';
          _activo = proveedor.activo == 1;
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando proveedor: $e')),
        );
      }
    }
  }

  Future<void> _saveProveedor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final proveedor = Proveedor(
        codigo: _proveedor?.codigo,
        razonSocial: _razonSocialController.text.trim(),
        nombre: _nombreController.text.trim().isEmpty
            ? null
            : _nombreController.text.trim(),
        apellido: _apellidoController.text.trim().isEmpty
            ? null
            : _apellidoController.text.trim(),
        cuit: _cuitController.text.trim().isEmpty
            ? null
            : _cuitController.text.trim(),
        domicilio: _domicilioController.text.trim().isEmpty
            ? null
            : _domicilioController.text.trim(),
        localidad: _localidadController.text.trim().isEmpty
            ? null
            : _localidadController.text.trim(),
        codigoPostal: _codigoPostalController.text.trim().isEmpty
            ? null
            : _codigoPostalController.text.trim(),
        telefono1: _telefono1Controller.text.trim().isEmpty
            ? null
            : _telefono1Controller.text.trim(),
        telefono2: _telefono2Controller.text.trim().isEmpty
            ? null
            : _telefono2Controller.text.trim(),
        mail: _mailController.text.trim().isEmpty
            ? null
            : _mailController.text.trim(),
        notas: _notasController.text.trim().isEmpty
            ? null
            : _notasController.text.trim(),
        cuenta: int.tryParse(_cuentaController.text.trim()),
        activo: _activo ? 1 : 0,
      );

      final notifier = ref.read(proveedoresNotifierProvider.notifier);

      if (isEditing) {
        await notifier.updateProveedor(proveedor);
      } else {
        await notifier.createProveedor(proveedor);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Proveedor actualizado correctamente'
                : 'Proveedor creado correctamente'),
          ),
        );
        context.go('/proveedores');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Proveedor' : 'Nuevo Proveedor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/proveedores'),
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
                    // Datos principales
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Datos Principales',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _razonSocialController,
                              decoration: const InputDecoration(
                                labelText: 'Razón Social *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.store),
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'La razón social es obligatoria';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _nombreController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.person),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _apellidoController,
                                    decoration: const InputDecoration(
                                      labelText: 'Apellido',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.person),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cuitController,
                              decoration: const InputDecoration(
                                labelText: 'CUIT',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.credit_card),
                                hintText: 'XX-XXXXXXXX-X',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cuentaController,
                              decoration: InputDecoration(
                                labelText: 'Cuenta Contable',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.account_tree),
                                hintText: 'Número de cuenta',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.search),
                                  tooltip: 'Buscar cuenta',
                                  onPressed: () async {
                                    final result = await showDialog<Cuenta>(
                                      context: context,
                                      builder: (_) => const CuentasSearchDialog(),
                                    );
                                    if (result != null) {
                                      setState(() {
                                        _cuentaController.text =
                                            result.cuenta.toString();
                                      });
                                    }
                                  },
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Domicilio
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Domicilio',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _domicilioController,
                              decoration: const InputDecoration(
                                labelText: 'Dirección',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_on),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _localidadController,
                                    decoration: const InputDecoration(
                                      labelText: 'Localidad',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.location_city),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _codigoPostalController,
                                    decoration: const InputDecoration(
                                      labelText: 'Código Postal',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.markunread_mailbox),
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

                    // Contacto
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contacto',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _telefono1Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Teléfono 1',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.phone),
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _telefono2Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Teléfono 2',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.phone),
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _mailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notas
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notasController,
                              decoration: const InputDecoration(
                                labelText: 'Observaciones',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.notes),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Estado (solo en edición)
                    if (isEditing)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Estado',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_proveedor?.codigo != null)
                                    Chip(
                                      avatar: const Icon(Icons.tag, size: 16),
                                      label: Text('Código: ${_proveedor!.codigo}'),
                                      backgroundColor: Colors.orange[50],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                value: _activo,
                                onChanged: (value) {
                                  setState(() => _activo = value);
                                },
                                title: Text(
                                  _activo ? 'Proveedor Activo' : 'Proveedor Inactivo',
                                  style: TextStyle(
                                    color: _activo ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  _activo
                                      ? 'El proveedor aparecerá en las búsquedas y listados'
                                      : 'El proveedor no aparecerá en las búsquedas',
                                ),
                                secondary: Icon(
                                  _activo ? Icons.check_circle : Icons.cancel,
                                  color: _activo ? Colors.green : Colors.red,
                                ),
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
                          onPressed: () => context.go('/proveedores'),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _saveProveedor,
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
