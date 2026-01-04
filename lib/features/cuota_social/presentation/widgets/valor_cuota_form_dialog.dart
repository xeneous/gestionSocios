import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/valor_cuota_social_model.dart';
import '../../providers/cuota_social_provider.dart';

class ValorCuotaFormDialog extends ConsumerStatefulWidget {
  final ValorCuotaSocial? valorExistente;

  const ValorCuotaFormDialog({
    super.key,
    this.valorExistente,
  });

  @override
  ConsumerState<ValorCuotaFormDialog> createState() => _ValorCuotaFormDialogState();
}

class _ValorCuotaFormDialogState extends ConsumerState<ValorCuotaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _anioInicioController;
  late final TextEditingController _mesInicioController;
  late final TextEditingController _anioCierreController;
  late final TextEditingController _mesCierreController;
  late final TextEditingController _valorResidenteController;
  late final TextEditingController _valorTitularController;

  bool _esPeriodoAbierto = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();

    if (widget.valorExistente != null) {
      final valor = widget.valorExistente!;
      final fechaInicio = ValorCuotaSocial.anioMesToDate(valor.anioMesInicio);

      _anioInicioController = TextEditingController(text: fechaInicio.year.toString());
      _mesInicioController = TextEditingController(text: fechaInicio.month.toString());

      if (valor.anioMesCierre != null) {
        final fechaCierre = ValorCuotaSocial.anioMesToDate(valor.anioMesCierre!);
        _anioCierreController = TextEditingController(text: fechaCierre.year.toString());
        _mesCierreController = TextEditingController(text: fechaCierre.month.toString());
        _esPeriodoAbierto = false;
      } else {
        _anioCierreController = TextEditingController();
        _mesCierreController = TextEditingController();
        _esPeriodoAbierto = true;
      }

      _valorResidenteController = TextEditingController(text: valor.valorResidente.toStringAsFixed(2));
      _valorTitularController = TextEditingController(text: valor.valorTitular.toStringAsFixed(2));
    } else {
      final ahora = DateTime.now();
      _anioInicioController = TextEditingController(text: ahora.year.toString());
      _mesInicioController = TextEditingController(text: ahora.month.toString());
      _anioCierreController = TextEditingController();
      _mesCierreController = TextEditingController();
      _valorResidenteController = TextEditingController();
      _valorTitularController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _anioInicioController.dispose();
    _mesInicioController.dispose();
    _anioCierreController.dispose();
    _mesCierreController.dispose();
    _valorResidenteController.dispose();
    _valorTitularController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.valorExistente != null;

    return AlertDialog(
      title: Text(esEdicion ? 'Editar Valor de Cuota' : 'Nuevo Valor de Cuota'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Período Inicio
                Text(
                  'Período de Inicio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _anioInicioController,
                        decoration: const InputDecoration(
                          labelText: 'Año',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          final anio = int.tryParse(value);
                          if (anio == null || anio < 2000 || anio > 2100) {
                            return 'Año inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _mesInicioController,
                        decoration: const InputDecoration(
                          labelText: 'Mes',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          final mes = int.tryParse(value);
                          if (mes == null || mes < 1 || mes > 12) {
                            return 'Mes inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Período Cierre
                Row(
                  children: [
                    Text(
                      'Período de Cierre',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Checkbox(
                          value: _esPeriodoAbierto,
                          onChanged: (value) {
                            setState(() {
                              _esPeriodoAbierto = value ?? true;
                              if (_esPeriodoAbierto) {
                                _anioCierreController.clear();
                                _mesCierreController.clear();
                              }
                            });
                          },
                        ),
                        const Text('Período Actual (sin cierre)'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _anioCierreController,
                        enabled: !_esPeriodoAbierto,
                        decoration: const InputDecoration(
                          labelText: 'Año',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (value) {
                          if (_esPeriodoAbierto) return null;

                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          final anio = int.tryParse(value);
                          if (anio == null || anio < 2000 || anio > 2100) {
                            return 'Año inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _mesCierreController,
                        enabled: !_esPeriodoAbierto,
                        decoration: const InputDecoration(
                          labelText: 'Mes',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        validator: (value) {
                          if (_esPeriodoAbierto) return null;

                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          final mes = int.tryParse(value);
                          if (mes == null || mes < 1 || mes > 12) {
                            return 'Mes inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Valores
                Text(
                  'Valores de Cuota',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _valorResidenteController,
                        decoration: const InputDecoration(
                          labelText: 'Valor Residente',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          final valor = double.tryParse(value);
                          if (valor == null || valor <= 0) {
                            return 'Valor inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _valorTitularController,
                        decoration: const InputDecoration(
                          labelText: 'Valor Titular',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          final valor = double.tryParse(value);
                          if (valor == null || valor <= 0) {
                            return 'Valor inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(esEdicion ? 'Actualizar' : 'Crear'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _guardando = true);

    try {
      final anioInicio = int.parse(_anioInicioController.text);
      final mesInicio = int.parse(_mesInicioController.text);
      final anioMesInicio = anioInicio * 100 + mesInicio;

      int? anioMesCierre;
      if (!_esPeriodoAbierto) {
        final anioCierre = int.parse(_anioCierreController.text);
        final mesCierre = int.parse(_mesCierreController.text);
        anioMesCierre = anioCierre * 100 + mesCierre;

        // Validar que el cierre sea mayor o igual al inicio
        if (anioMesCierre < anioMesInicio) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('El período de cierre debe ser posterior al de inicio'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _guardando = false);
          return;
        }
      }

      final valorResidente = double.parse(_valorResidenteController.text);
      final valorTitular = double.parse(_valorTitularController.text);

      final notifier = ref.read(valoresCuotaNotifierProvider.notifier);

      if (widget.valorExistente != null) {
        // Actualizar
        await notifier.actualizar(
          id: widget.valorExistente!.id,
          anioMesInicio: anioMesInicio,
          anioMesCierre: anioMesCierre,
          valorResidente: valorResidente,
          valorTitular: valorTitular,
        );
      } else {
        // Crear
        await notifier.crear(
          anioMesInicio: anioMesInicio,
          anioMesCierre: anioMesCierre,
          valorResidente: valorResidente,
          valorTitular: valorTitular,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.valorExistente != null
                  ? 'Valor actualizado correctamente'
                  : 'Valor creado correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
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
      setState(() => _guardando = false);
    }
  }
}
