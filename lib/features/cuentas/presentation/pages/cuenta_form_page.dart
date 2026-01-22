import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cuentas_provider.dart';
import '../../models/cuenta_model.dart';

class CuentaFormPage extends ConsumerStatefulWidget {
  final int? cuentaId;
  
  const CuentaFormPage({this.cuentaId, super.key});

  @override
  ConsumerState<CuentaFormPage> createState() => _CuentaFormPageState();
}

class _CuentaFormPageState extends ConsumerState<CuentaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _cuentaController = TextEditingController();
  final _cortaController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _descripcionResumidaController = TextEditingController();
  final _siglaController = TextEditingController();
  
  bool _imputable = true;
  bool _activo = true;
  bool _isLoading = false;
  Cuenta? _currentCuenta;

  @override
  void initState() {
    super.initState();
    if (widget.cuentaId != null) {
      _loadCuenta();
    }
  }

  Future<void> _loadCuenta() async {
    setState(() => _isLoading = true);
    try {
      final cuenta = await ref
          .read(cuentasNotifierProvider.notifier)
          .getCuentaByCuenta(widget.cuentaId!);
      
      if (cuenta != null && mounted) {
        setState(() {
          _currentCuenta = cuenta;
          _cuentaController.text = cuenta.cuenta.toString();
          _cortaController.text = cuenta.corta?.toString() ?? '';
          _descripcionController.text = cuenta.descripcion;
          _descripcionResumidaController.text = cuenta.descripcionResumida ?? '';
          _siglaController.text = cuenta.sigla ?? '';
          _imputable = cuenta.imputable;
          _activo = cuenta.activo;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _cuentaController.dispose();
    _cortaController.dispose();
    _descripcionController.dispose();
    _descripcionResumidaController.dispose();
    _siglaController.dispose();
    super.dispose();
  }

  Future<void> _saveCuenta() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cuenta = Cuenta(
        cuenta: int.parse(_cuentaController.text),
        corta: _cortaController.text.isEmpty 
            ? null 
            : int.tryParse(_cortaController.text),
        descripcion: _descripcionController.text,
        descripcionResumida: _descripcionResumidaController.text.isEmpty
            ? null
            : _descripcionResumidaController.text,
        sigla: _siglaController.text.isEmpty ? null : _siglaController.text,
        imputable: _imputable,
        activo: _activo,
      );

      if (widget.cuentaId == null) {
        await ref.read(cuentasNotifierProvider.notifier).createCuenta(cuenta);
      } else {
        await ref
            .read(cuentasNotifierProvider.notifier)
            .updateCuenta(widget.cuentaId!, cuenta);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.cuentaId == null
                ? 'Cuenta creada correctamente'
                : 'Cuenta actualizada correctamente'),
          ),
        );
        context.go('/cuentas');
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
        title: Text(widget.cuentaId == null ? 'Nueva Cuenta' : 'Editar Cuenta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.cuentaId == null
                                  ? 'Crear Nueva Cuenta'
                                  : 'Editar Cuenta',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _cuentaController,
                                    decoration: const InputDecoration(
                                      labelText: 'Número de Cuenta *',
                                      border: OutlineInputBorder(),
                                      helperText: 'Número completo de cuenta',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Campo requerido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cortaController,
                                    decoration: const InputDecoration(
                                      labelText: 'Cuenta Corta',
                                      border: OutlineInputBorder(),
                                      helperText: 'Para carga rápida',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descripcionController,
                              decoration: const InputDecoration(
                                labelText: 'Descripción *',
                                border: OutlineInputBorder(),
                              ),
                              maxLength: 100,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Campo requerido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descripcionResumidaController,
                              decoration: const InputDecoration(
                                labelText: 'Descripción Resumida',
                                border: OutlineInputBorder(),
                                helperText: 'Para reportes',
                              ),
                              maxLength: 50,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _siglaController,
                              decoration: const InputDecoration(
                                labelText: 'Sigla',
                                border: OutlineInputBorder(),
                              ),
                              maxLength: 10,
                            ),
                            const SizedBox(height: 24),
                            SwitchListTile(
                              title: const Text('Imputable'),
                              subtitle: const Text(
                                'Permite registrar movimientos en esta cuenta',
                              ),
                              value: _imputable,
                              onChanged: (value) {
                                setState(() => _imputable = value);
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Activo'),
                              subtitle: const Text(
                                'La cuenta aparecerá en las listas',
                              ),
                              value: _activo,
                              onChanged: (value) {
                                setState(() => _activo = value);
                              },
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => context.go('/cuentas'),
                                  child: const Text('Cancelar'),
                                ),
                                const SizedBox(width: 16),
                                FilledButton(
                                  onPressed: _isLoading ? null : _saveCuenta,
                                  child: Text(widget.cuentaId == null
                                      ? 'Crear Cuenta'
                                      : 'Guardar Cambios'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
