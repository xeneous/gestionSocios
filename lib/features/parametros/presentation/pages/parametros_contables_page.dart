import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/parametros_provider.dart';
import '../../models/parametro_contable_model.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class ParametrosContablesPage extends ConsumerStatefulWidget {
  const ParametrosContablesPage({super.key});

  @override
  ConsumerState<ParametrosContablesPage> createState() =>
      _ParametrosContablesPageState();
}

class _ParametrosContablesPageState
    extends ConsumerState<ParametrosContablesPage> {
  final _cuentaProveedoresController = TextEditingController();
  final _cuentaClientesController = TextEditingController();
  final _cuentaSponsorsController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _cuentaProveedoresController.dispose();
    _cuentaClientesController.dispose();
    _cuentaSponsorsController.dispose();
    super.dispose();
  }

  Future<void> _guardarParametros() async {
    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(parametrosNotifierProvider.notifier);

      await notifier.actualizarParametro(
        ParametroContable.cuentaProveedores,
        _cuentaProveedoresController.text.trim().isEmpty
            ? null
            : _cuentaProveedoresController.text.trim(),
      );

      await notifier.actualizarParametro(
        ParametroContable.cuentaClientes,
        _cuentaClientesController.text.trim().isEmpty
            ? null
            : _cuentaClientesController.text.trim(),
      );

      await notifier.actualizarParametro(
        ParametroContable.cuentaSponsors,
        _cuentaSponsorsController.text.trim().isEmpty
            ? null
            : _cuentaSponsorsController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parámetros guardados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
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
    final parametrosAsync = ref.watch(parametrosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parámetros Contables'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/parametros-contables'),
      body: parametrosAsync.when(
        data: (parametros) {
          // Cargar valores iniciales
          final proveedores = parametros
              .where((p) => p.clave == ParametroContable.cuentaProveedores)
              .firstOrNull;
          final clientes = parametros
              .where((p) => p.clave == ParametroContable.cuentaClientes)
              .firstOrNull;
          final sponsors = parametros
              .where((p) => p.clave == ParametroContable.cuentaSponsors)
              .firstOrNull;

          if (_cuentaProveedoresController.text.isEmpty && proveedores?.valor != null) {
            _cuentaProveedoresController.text = proveedores!.valor!;
          }
          if (_cuentaClientesController.text.isEmpty && clientes?.valor != null) {
            _cuentaClientesController.text = clientes!.valor!;
          }
          if (_cuentaSponsorsController.text.isEmpty && sponsors?.valor != null) {
            _cuentaSponsorsController.text = sponsors!.valor!;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.settings, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Cuentas Contables para Imputación',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Configure las cuentas contables que se utilizarán en los asientos automáticos de compras, ventas, cobranzas y pagos.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _cuentaProveedoresController,
                          decoration: const InputDecoration(
                            labelText: 'Cuenta Proveedores (Pasivo)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.store, color: Colors.orange),
                            hintText: 'Ej: 21100100',
                            helperText: 'Cuenta para registrar deudas con proveedores',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cuentaClientesController,
                          decoration: const InputDecoration(
                            labelText: 'Cuenta Clientes (Activo)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business, color: Colors.blue),
                            hintText: 'Ej: 11310100',
                            helperText: 'Cuenta para registrar deudas de clientes',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cuentaSponsorsController,
                          decoration: const InputDecoration(
                            labelText: 'Cuenta Sponsors (Activo)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.handshake, color: Colors.green),
                            hintText: 'Ej: 11310200',
                            helperText: 'Cuenta para registrar deudas de sponsors',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FilledButton.icon(
                              onPressed: _isLoading ? null : _guardarParametros,
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
                              label: const Text('Guardar Parámetros'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(parametrosProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
