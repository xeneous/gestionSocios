import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/conceptos_provider.dart';
import '../../models/concepto_model.dart';

/// Página de formulario para crear/editar conceptos
class ConceptoFormPage extends ConsumerStatefulWidget {
  final String? conceptoCodigo;

  const ConceptoFormPage({
    super.key,
    this.conceptoCodigo,
  });

  @override
  ConsumerState<ConceptoFormPage> createState() => _ConceptoFormPageState();
}

class _ConceptoFormPageState extends ConsumerState<ConceptoFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _codigoController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _entidadController;
  late final TextEditingController _modalidadController;
  late final TextEditingController _importeController;
  late final TextEditingController _grupoController;

  // State
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    _codigoController = TextEditingController();
    _descripcionController = TextEditingController();
    _entidadController = TextEditingController(text: '0');
    _modalidadController = TextEditingController();
    _importeController = TextEditingController();
    _grupoController = TextEditingController();

    if (widget.conceptoCodigo != null) {
      _loadConcepto();
    }
  }

  Future<void> _loadConcepto() async {
    final concepto = await ref
        .read(conceptoByCodigoProvider(widget.conceptoCodigo!).future);
    if (concepto != null && mounted) {
      setState(() {
        _codigoController.text = concepto.concepto;
        _descripcionController.text = concepto.descripcion ?? '';
        _entidadController.text = concepto.entidad?.toString() ?? '0';
        _modalidadController.text = concepto.modalidad ?? '';
        _importeController.text =
            concepto.importe?.toStringAsFixed(2) ?? '';
        _grupoController.text = concepto.grupo ?? '';
        _activo = concepto.activo;
      });
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _descripcionController.dispose();
    _entidadController.dispose();
    _modalidadController.dispose();
    _importeController.dispose();
    _grupoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.conceptoCodigo != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Concepto' : 'Nuevo Concepto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Ir al inicio',
          ),
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
            // Código
            TextFormField(
              controller: _codigoController,
              decoration: const InputDecoration(
                labelText: 'Código *',
                border: OutlineInputBorder(),
                helperText: 'Código de 3 caracteres (ej: CS, MAE)',
              ),
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              enabled: !isEditing,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El código es obligatorio';
                }
                if (value.length != 3) {
                  return 'El código debe tener exactamente 3 caracteres';
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

            // Entidad
            TextFormField(
              controller: _entidadController,
              decoration: const InputDecoration(
                labelText: 'Entidad',
                border: OutlineInputBorder(),
                helperText: '0=SAO, 1=FUNDOSA',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),

            // Modalidad
            TextFormField(
              controller: _modalidadController,
              decoration: const InputDecoration(
                labelText: 'Modalidad',
                border: OutlineInputBorder(),
                helperText: 'I=Individual, etc.',
              ),
              maxLength: 1,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),

            // Importe
            TextFormField(
              controller: _importeController,
              decoration: const InputDecoration(
                labelText: 'Importe',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: 16),

            // Grupo
            TextFormField(
              controller: _grupoController,
              decoration: const InputDecoration(
                labelText: 'Grupo',
                border: OutlineInputBorder(),
                helperText: 'A, B, C, etc.',
              ),
              maxLength: 1,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 24),

            // Activo
            Card(
              child: SwitchListTile(
                title: const Text('Activo'),
                subtitle: const Text(
                    'Solo conceptos activos se muestran en formularios'),
                value: _activo,
                onChanged: (value) => setState(() => _activo = value),
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

    final concepto = Concepto(
      concepto: _codigoController.text.toUpperCase(),
      descripcion: _descripcionController.text,
      entidad: _entidadController.text.isEmpty
          ? null
          : int.tryParse(_entidadController.text),
      modalidad: _modalidadController.text.isEmpty
          ? null
          : _modalidadController.text.toUpperCase(),
      importe: _importeController.text.isEmpty
          ? null
          : double.tryParse(_importeController.text),
      grupo: _grupoController.text.isEmpty
          ? null
          : _grupoController.text.toUpperCase(),
      activo: _activo,
    );

    try {
      if (widget.conceptoCodigo != null) {
        await ref
            .read(conceptosNotifierProvider.notifier)
            .updateConcepto(widget.conceptoCodigo!, concepto);
      } else {
        await ref
            .read(conceptosNotifierProvider.notifier)
            .createConcepto(concepto);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.conceptoCodigo != null
                ? 'Concepto actualizado correctamente'
                : 'Concepto creado correctamente'),
          ),
        );
        context.go('/conceptos');
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
          .read(conceptosNotifierProvider.notifier)
          .deleteConcepto(widget.conceptoCodigo!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Concepto eliminado correctamente')),
        );
        context.go('/conceptos');
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
