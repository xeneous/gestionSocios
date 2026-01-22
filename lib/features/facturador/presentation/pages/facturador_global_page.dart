import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';
import '../../models/facturacion_previa_model.dart';
import '../../providers/facturador_provider.dart';

/// Página del facturador global de cuotas sociales
class FacturadorGlobalPage extends ConsumerStatefulWidget {
  const FacturadorGlobalPage({super.key});

  @override
  ConsumerState<FacturadorGlobalPage> createState() =>
      _FacturadorGlobalPageState();
}

class _FacturadorGlobalPageState extends ConsumerState<FacturadorGlobalPage> {
  int _anioDesde = DateTime.now().year;
  int _mesDesde = DateTime.now().month;
  int _anioHasta = DateTime.now().year;
  int _mesHasta = DateTime.now().month;

  List<PeriodoFacturacion>? _periodosSeleccionados;
  bool _mostrandoPrevia = false;

  @override
  Widget build(BuildContext context) {
    final userRole = ref.watch(userRoleProvider);

    // Verificar permisos
    if (!userRole.puedeFacturarMasivo) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Denegado')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'No tiene permisos para acceder a esta función',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Requiere rol: Supervisor o Administrador',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturador Global de Cuotas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Ir al inicio',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card de instrucciones
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Facturador Masivo de Cuotas Sociales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esta función genera cuotas sociales (CS) para todos los socios Asistentes (A) y Titulares (T) '
                      'que NO tengan cuotas creadas en los meses seleccionados.',
                      style: TextStyle(color: Colors.blue[800]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Se respetan los valores de residente/no residente de cada socio\n'
                      '• Solo se generan cuotas para meses faltantes\n'
                      '• Se puede ver una vista previa antes de confirmar',
                      style: TextStyle(
                          fontSize: 12, color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Selección de período
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seleccionar Período a Facturar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Desde
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Desde',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _mesDesde,
                                      decoration: const InputDecoration(
                                        labelText: 'Mes',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: List.generate(12, (i) => i + 1)
                                          .map((mes) => DropdownMenuItem(
                                                value: mes,
                                                child: Text(_getNombreMes(mes)),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _mesDesde = value);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _anioDesde,
                                      decoration: const InputDecoration(
                                        labelText: 'Año',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: List.generate(5, (i) => 2024 + i)
                                          .map((anio) => DropdownMenuItem(
                                                value: anio,
                                                child: Text(anio.toString()),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _anioDesde = value);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Hasta
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hasta',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _mesHasta,
                                      decoration: const InputDecoration(
                                        labelText: 'Mes',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: List.generate(12, (i) => i + 1)
                                          .map((mes) => DropdownMenuItem(
                                                value: mes,
                                                child: Text(_getNombreMes(mes)),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _mesHasta = value);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _anioHasta,
                                      decoration: const InputDecoration(
                                        labelText: 'Año',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: List.generate(5, (i) => 2024 + i)
                                          .map((anio) => DropdownMenuItem(
                                                value: anio,
                                                child: Text(anio.toString()),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _anioHasta = value);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _generarVistaPrevia,
                      icon: const Icon(Icons.preview),
                      label: const Text('Generar Vista Previa'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Vista previa
            if (_mostrandoPrevia && _periodosSeleccionados != null)
              Expanded(
                child: _buildVistaPrevia(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaPrevia() {
    final vistaPreviaAsync =
        ref.watch(vistaPreviaFacturacionProvider(_periodosSeleccionados!));

    return vistaPreviaAsync.when(
      data: (resumen) {
        if (resumen.items.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay cuotas pendientes de generar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos los socios Asistentes y Titulares ya tienen sus cuotas creadas para el período seleccionado.',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resumen
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Resumen de Facturación',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildResumenItem(
                          'Socios',
                          resumen.totalSocios.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                        _buildResumenItem(
                          'Cuotas',
                          resumen.totalCuotas.toString(),
                          Icons.receipt,
                          Colors.orange,
                        ),
                        _buildResumenItem(
                          'Total',
                          '\$${resumen.totalImporte.toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Tabla de items
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.grey[200],
                      child: const Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child: Text('Socio',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              child: Text('Grupo',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text('Meses',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              child: Text('Importe',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: resumen.items.length,
                        itemBuilder: (context, index) {
                          final item = resumen.items[index];
                          return ListTile(
                            dense: true,
                            title: Row(
                              children: [
                                Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(item.socioNombre)),
                                        if (item.tieneDescuento50)
                                          Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              '50%',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                      ],
                                    )),
                                Expanded(child: Text(item.socioGrupo)),
                                Expanded(
                                    flex: 2,
                                    child: Text('${item.cantidadMeses} mes(es)')),
                                Expanded(
                                    child: Text(
                                        '\$${item.importeTotal.toStringAsFixed(2)}')),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botón confirmar
            FilledButton.icon(
              onPressed: () => _confirmarGeneracion(resumen),
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirmar y Generar Cuotas'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error al generar vista previa: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumenItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[700]),
        ),
      ],
    );
  }

  void _generarVistaPrevia() {
    // Validar que la fecha desde no sea mayor que hasta
    final desde = DateTime(_anioDesde, _mesDesde);
    final hasta = DateTime(_anioHasta, _mesHasta);

    if (desde.isAfter(hasta)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha desde no puede ser mayor que la fecha hasta'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Generar lista de períodos
    final periodos = <PeriodoFacturacion>[];
    var current = DateTime(_anioDesde, _mesDesde);
    final end = DateTime(_anioHasta, _mesHasta);

    while (
        current.isBefore(end) || (current.year == end.year && current.month == end.month)) {
      periodos.add(PeriodoFacturacion(anio: current.year, mes: current.month));
      current = DateTime(current.year, current.month + 1);
    }

    setState(() {
      _periodosSeleccionados = periodos;
      _mostrandoPrevia = true;
    });
  }

  Future<void> _confirmarGeneracion(ResumenFacturacion resumen) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Generación'),
        content: Text(
          '¿Está seguro que desea generar ${resumen.totalCuotas} cuotas '
          'para ${resumen.totalSocios} socios por un total de \$${resumen.totalImporte.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mostrar diálogo de progreso
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProgressDialog(resumen: resumen),
    );
  }

  String _getNombreMes(int mes) {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return meses[mes - 1];
  }
}

// Diálogo de progreso
class _ProgressDialog extends ConsumerStatefulWidget {
  final ResumenFacturacion resumen;

  const _ProgressDialog({required this.resumen});

  @override
  ConsumerState<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends ConsumerState<_ProgressDialog> {
  final _progresoNotifier = ValueNotifier<ProgresoGeneracion>(
    ProgresoGeneracion(0, 0),
  );
  StreamController<ProgresoGeneracion>? _progresoController;

  @override
  void initState() {
    super.initState();
    _ejecutarGeneracion();
  }

  @override
  void dispose() {
    _progresoController?.close();
    _progresoNotifier.dispose();
    super.dispose();
  }

  Future<void> _ejecutarGeneracion() async {
    _progresoController = StreamController<ProgresoGeneracion>();
    _progresoNotifier.value = ProgresoGeneracion(0, widget.resumen.totalCuotas);

    // Escuchar el stream y actualizar el ValueNotifier (no usa setState)
    _progresoController!.stream.listen((progreso) {
      _progresoNotifier.value = progreso;
    });

    try {
      // Llamar directamente al servicio SIN pasar por el notifier de Riverpod
      final service = ref.read(facturadorServiceProvider);

      await service.generarCuotasMasivas(
        resumen: widget.resumen,
        onProgress: (current, total) {
          _progresoController?.add(ProgresoGeneracion(current, total));
        },
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${widget.resumen.totalCuotas} cuotas generadas correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar cuotas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generando Cuotas'),
      content: ValueListenableBuilder<ProgresoGeneracion>(
        valueListenable: _progresoNotifier,
        builder: (context, progreso, child) {
          final porcentaje = progreso.porcentaje;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Procesando: ${progreso.actual} / ${progreso.total}',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                '${(porcentaje * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: porcentaje),
            ],
          );
        },
      ),
    );
  }
}
