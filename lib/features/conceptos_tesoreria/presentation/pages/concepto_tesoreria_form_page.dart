import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../cuentas_corrientes/providers/conceptos_tesoreria_provider.dart';
import '../../../cuentas_corrientes/models/concepto_tesoreria_model.dart';

/// Página de formulario para crear/editar conceptos de tesorería
class ConceptoTesoreriaFormPage extends ConsumerStatefulWidget {
  final int? conceptoId;

  const ConceptoTesoreriaFormPage({
    super.key,
    this.conceptoId,
  });

  @override
  ConsumerState<ConceptoTesoreriaFormPage> createState() =>
      _ConceptoTesoreriaFormPageState();
}

class _ConceptoTesoreriaFormPageState
    extends ConsumerState<ConceptoTesoreriaFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _idController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _imputacionContableController;
  late final TextEditingController _modalidadController;
  late final TextEditingController _unificadorController;

  // State
  String _ci = 'N';
  String _ce = 'N';
  bool _mostrador = false;
  bool _monedaExtranjera = false;
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _descripcionController = TextEditingController();
    _imputacionContableController = TextEditingController();
    _modalidadController = TextEditingController(text: '0');
    _unificadorController = TextEditingController();

    if (widget.conceptoId != null) {
      _loadConcepto();
    }
  }

  Future<void> _loadConcepto() async {
    final concepto = await ref.read(conceptoTesoreriaByIdProvider(widget.conceptoId!).future);
    if (concepto != null && mounted) {
      setState(() {
        _idController.text = concepto.id.toString();
        _descripcionController.text = concepto.descripcion ?? '';
        _imputacionContableController.text = concepto.imputacionContable ?? '';
        _modalidadController.text = concepto.modalidad.toString();
        _unificadorController.text = concepto.unificador?.toString() ?? '';
        _ci = concepto.ci;
        _ce = concepto.ce;
        _mostrador = concepto.esDisponibleMostrador;
        _monedaExtranjera = concepto.aceptaMonedaExtranjera;
        _activo = concepto.activo;
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _descripcionController.dispose();
    _imputacionContableController.dispose();
    _modalidadController.dispose();
    _unificadorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.conceptoId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Concepto' : 'Nuevo Concepto'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteConcepto,
              tooltip: 'Eliminar',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ID
            TextFormField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'ID *',
                border: OutlineInputBorder(),
                helperText: 'Número identificador único',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !isEditing,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El ID es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Descripción
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La descripción es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Imputación Contable
            TextFormField(
              controller: _imputacionContableController,
              decoration: const InputDecoration(
                labelText: 'Cuenta Contable',
                border: OutlineInputBorder(),
                helperText: 'Número de cuenta para imputación contable',
              ),
            ),
            const SizedBox(height: 16),

            // Modalidad
            TextFormField(
              controller: _modalidadController,
              decoration: const InputDecoration(
                labelText: 'Modalidad',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),

            // Unificador
            TextFormField(
              controller: _unificadorController,
              decoration: const InputDecoration(
                labelText: 'Unificador',
                border: OutlineInputBorder(),
                helperText: 'ID para agrupar conceptos relacionados',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 24),

            // Cartera de Ingreso/Egreso
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cartera',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Ingreso (CI)'),
                            subtitle: const Text('Para cobranzas'),
                            value: 'I',
                            groupValue: _ci == 'S' ? 'I' : (_ce == 'S' ? 'E' : 'N'),
                            onChanged: (value) {
                              setState(() {
                                _ci = 'S';
                                _ce = 'N';
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Egreso (CE)'),
                            subtitle: const Text('Para pagos'),
                            value: 'E',
                            groupValue: _ci == 'S' ? 'I' : (_ce == 'S' ? 'E' : 'N'),
                            onChanged: (value) {
                              setState(() {
                                _ci = 'N';
                                _ce = 'S';
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

            // Opciones
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Opciones',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Disponible en mostrador'),
                      value: _mostrador,
                      onChanged: (value) => setState(() => _mostrador = value),
                    ),
                    SwitchListTile(
                      title: const Text('Acepta moneda extranjera'),
                      value: _monedaExtranjera,
                      onChanged: (value) => setState(() => _monedaExtranjera = value),
                    ),
                    SwitchListTile(
                      title: const Text('Activo'),
                      subtitle: const Text('Solo conceptos activos se muestran en formularios'),
                      value: _activo,
                      onChanged: (value) => setState(() => _activo = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _saveConcepto,
                    child: Text(isEditing ? 'Actualizar' : 'Crear'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConcepto() async {
    if (!_formKey.currentState!.validate()) return;

    final concepto = ConceptoTesoreria(
      id: int.parse(_idController.text),
      descripcion: _descripcionController.text,
      imputacionContable: _imputacionContableController.text.isEmpty
          ? null
          : _imputacionContableController.text,
      modalidad: int.tryParse(_modalidadController.text) ?? 0,
      ci: _ci,
      ce: _ce,
      unificador: _unificadorController.text.isEmpty
          ? null
          : int.tryParse(_unificadorController.text),
      mostrador: _mostrador ? 1 : 0,
      monedaExtranjera: _monedaExtranjera ? 1 : 0,
      activo: _activo,
    );

    try {
      if (widget.conceptoId != null) {
        await ref
            .read(conceptosTesoreriaNotifierProvider.notifier)
            .updateConcepto(widget.conceptoId!, concepto);
      } else {
        await ref
            .read(conceptosTesoreriaNotifierProvider.notifier)
            .createConcepto(concepto);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.conceptoId != null
                ? 'Concepto actualizado correctamente'
                : 'Concepto creado correctamente'),
          ),
        );
        context.go('/conceptos-tesoreria');
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

  Future<void> _deleteConcepto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Concepto'),
        content: const Text('¿Está seguro que desea eliminar este concepto?'),
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

    if (confirmed != true) return;

    try {
      await ref
          .read(conceptosTesoreriaNotifierProvider.notifier)
          .deleteConcepto(widget.conceptoId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Concepto eliminado correctamente')),
        );
        context.go('/conceptos-tesoreria');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
