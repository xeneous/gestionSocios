import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import '../../../../core/utils/web_utils.dart';

import '../../providers/rechazos_mastercard_provider.dart';

class RechazosMastercardPage extends ConsumerWidget {
  const RechazosMastercardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechazosMastercardProvider);
    final notifier = ref.read(rechazosMastercardProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechazos Mastercard'),
        actions: [
          if (state.estado != RechazosMastercardEstado.inicial)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Nuevo archivo',
              onPressed: notifier.reiniciar,
            ),
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Inicio',
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Abrir en nueva pestaña',
            onPressed: () => abrirEnNuevaPestana('/rechazos-mastercard'),
          ),
        ],
      ),
      body: switch (state.estado) {
        RechazosMastercardEstado.inicial =>
          _PanelSeleccionArchivo(notifier: notifier),
        RechazosMastercardEstado.buscando => const _PanelCargando(
            mensaje: 'Buscando débitos en cuenta corriente...'),
        RechazosMastercardEstado.registrando =>
          const _PanelCargando(mensaje: 'Procesando...'),
        RechazosMastercardEstado.listo =>
          _PanelResultados(state: state, notifier: notifier),
        RechazosMastercardEstado.completado =>
          _PanelCompletado(state: state, notifier: notifier),
        RechazosMastercardEstado.error =>
          _PanelError(state: state, notifier: notifier),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Panel: selección de fecha + archivo
// ---------------------------------------------------------------------------

class _PanelSeleccionArchivo extends StatefulWidget {
  final RechazosMastercardNotifier notifier;
  const _PanelSeleccionArchivo({required this.notifier});

  @override
  State<_PanelSeleccionArchivo> createState() => _PanelSeleccionArchivoState();
}

class _PanelSeleccionArchivoState extends State<_PanelSeleccionArchivo> {
  DateTime? _fechaPresentacion;
  final _fmtFecha = DateFormat('dd/MM/yyyy');

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaPresentacion ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
      helpText: 'Fecha de presentación original',
      locale: const Locale('es', 'AR'),
    );
    if (picked != null) {
      setState(() => _fechaPresentacion = picked);
    }
  }

  void _seleccionarArchivo() {
    if (_fechaPresentacion == null) return;
    final fecha = _fechaPresentacion!;

    final input = html.FileUploadInputElement();
    input.accept = '.txt,.csv';
    input.click();

    input.onChange.listen((event) {
      final file = input.files![0];
      final reader = html.FileReader();
      reader.readAsText(file, 'utf-8');
      reader.onLoad.listen((_) {
        final contenido = reader.result as String;
        widget.notifier.procesarArchivo(contenido, file.name, fecha);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.credit_card_off, size: 64, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                'Procesar archivo de rechazos Mastercard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),

              // Selector de fecha
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _fechaPresentacion == null
                      ? 'Seleccionar fecha de presentación'
                      : 'Presentación: ${_fmtFecha.format(_fechaPresentacion!)}',
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  foregroundColor: _fechaPresentacion == null
                      ? null
                      : Theme.of(context).colorScheme.primary,
                ),
                onPressed: _pickFecha,
              ),
              const SizedBox(height: 16),

              // Botón de archivo (solo activo cuando hay fecha)
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Seleccionar archivo .txt'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                onPressed:
                    _fechaPresentacion == null ? null : _seleccionarArchivo,
              ),

              if (_fechaPresentacion == null) ...[
                const SizedBox(height: 12),
                Text(
                  'Primero seleccioná la fecha de presentación',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel: cargando
// ---------------------------------------------------------------------------

class _PanelCargando extends StatelessWidget {
  final String mensaje;
  const _PanelCargando({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(mensaje, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel: resultados con tabs (Rechazos / Observados)
// ---------------------------------------------------------------------------

class _PanelResultados extends StatefulWidget {
  final RechazosMastercardState state;
  final RechazosMastercardNotifier notifier;
  const _PanelResultados({required this.state, required this.notifier});

  @override
  State<_PanelResultados> createState() => _PanelResultadosState();
}

class _PanelResultadosState extends State<_PanelResultados>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmar(BuildContext context) {
    final state = widget.state;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar procesamiento'),
        content: Text(
          '${[
            if (state.rechazosSeleccionados > 0)
              '• ${state.rechazosSeleccionados} rechazo(s) RDA a registrar en CC.',
            if (state.observadosSeleccionados > 0)
              '• ${state.observadosSeleccionados} tarjeta(s) a actualizar.',
          ].join('\n')}\n\nEsta acción no se puede deshacer. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.notifier.confirmar();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifier = widget.notifier;
    final fmt = NumberFormat('#,##0.00', 'es_AR');
    final fmtFecha = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        // Resumen general
        Container(
          width: double.infinity,
          color: Colors.blueGrey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _ChipInfo(
                label: 'Archivo',
                valor: state.nombreArchivo ?? '',
                color: Colors.blueGrey,
              ),
              _ChipInfo(
                label: 'Fecha presentación',
                valor: state.fechaPresentacion != null
                    ? fmtFecha.format(state.fechaPresentacion!)
                    : '-',
                color: Colors.blueGrey,
              ),
              _ChipInfo(
                label: 'Rechazos',
                valor: '${state.totalRechazos}',
                color: Colors.red,
              ),
              _ChipInfo(
                label: 'Observados',
                valor: '${state.totalObservados}',
                color: Colors.orange,
              ),
              _ChipInfo(
                label: 'Seleccionados',
                valor: '${state.totalSeleccionados}',
                color: Colors.blue,
              ),
            ],
          ),
        ),

        // Botón confirmar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.check_circle),
                label: Text('Confirmar (${state.totalSeleccionados})'),
                onPressed: state.totalSeleccionados == 0
                    ? null
                    : () => _confirmar(context),
              ),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Rechazos (${state.totalRechazos})',
              icon: const Icon(Icons.cancel),
            ),
            Tab(
              text: 'Observados (${state.totalObservados})',
              icon: const Icon(Icons.swap_horiz),
            ),
          ],
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Rechazos
              _TabRechazos(
                state: state,
                notifier: notifier,
                fmt: fmt,
              ),
              // Tab 2: Observados
              _TabObservados(
                state: state,
                notifier: notifier,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Rechazos
// ---------------------------------------------------------------------------

class _TabRechazos extends StatelessWidget {
  final RechazosMastercardState state;
  final RechazosMastercardNotifier notifier;
  final NumberFormat fmt;
  const _TabRechazos(
      {required this.state, required this.notifier, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final rechazos = state.soloRechazos;

    if (rechazos.isEmpty) {
      return const Center(child: Text('No hay rechazos en este archivo.'));
    }

    return Column(
      children: [
        // Barra de acciones
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _ChipInfo(
                label: 'DA encontrados',
                valor: '${state.rechazosEncontrados}',
                color: Colors.green,
              ),
              const SizedBox(width: 16),
              _ChipInfo(
                label: 'Sin DA en CC',
                valor: '${state.rechazosNoEncontrados}',
                color:
                    state.rechazosNoEncontrados > 0 ? Colors.red : Colors.grey,
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('Todos'),
                onPressed: () => notifier.toggleTodosRechazos(true),
              ),
              TextButton.icon(
                icon: const Icon(Icons.deselect, size: 18),
                label: const Text('Ninguno'),
                onPressed: () => notifier.toggleTodosRechazos(false),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rechazos.length,
            itemBuilder: (context, index) {
              final r = rechazos[index];
              // Encontrar índice real en resultados para toggleSeleccion
              final indexReal = state.resultados.indexOf(r);
              final encontrado = r.daEncontrado;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: encontrado ? null : Colors.red.shade50,
                child: CheckboxListTile(
                  value: r.seleccionado,
                  onChanged: encontrado
                      ? (_) => notifier.toggleSeleccion(indexReal)
                      : null,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.socioNombre ?? 'Socio ${r.item.socioId}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '\$ ${fmt.format(r.item.importe)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        'Período: ${r.item.documentoNumero}  •  Tarjeta: ...${r.item.tarjetaActual.length >= 4 ? r.item.tarjetaActual.substring(r.item.tarjetaActual.length - 4) : r.item.tarjetaActual}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r.item.motivo,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: encontrado
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              encontrado
                                  ? 'DA encontrado'
                                  : 'DA no encontrado en CC',
                              style: TextStyle(
                                fontSize: 11,
                                color: encontrado ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Observados (actualización de tarjeta)
// ---------------------------------------------------------------------------

class _TabObservados extends StatelessWidget {
  final RechazosMastercardState state;
  final RechazosMastercardNotifier notifier;
  const _TabObservados({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final observados = state.soloObservados;

    if (observados.isEmpty) {
      return const Center(child: Text('No hay observados en este archivo.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                'Se actualizará el número de tarjeta en el sistema',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('Todos'),
                onPressed: () => notifier.toggleTodosObservados(true),
              ),
              TextButton.icon(
                icon: const Icon(Icons.deselect, size: 18),
                label: const Text('Ninguno'),
                onPressed: () => notifier.toggleTodosObservados(false),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: observados.length,
            itemBuilder: (context, index) {
              final r = observados[index];
              final indexReal = state.resultados.indexOf(r);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: CheckboxListTile(
                  value: r.seleccionado,
                  onChanged: (_) => notifier.toggleSeleccion(indexReal),
                  title: Text(
                    r.socioNombre ?? 'Socio ${r.item.socioId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.credit_card,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Actual:  ...${r.item.tarjetaActual.length >= 4 ? r.item.tarjetaActual.substring(r.item.tarjetaActual.length - 4) : r.item.tarjetaActual}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.arrow_forward,
                              size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Nueva:  ...${r.item.tarjetaNueva.length >= 4 ? r.item.tarjetaNueva.substring(r.item.tarjetaNueva.length - 4) : r.item.tarjetaNueva}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Panel: completado
// ---------------------------------------------------------------------------

class _PanelCompletado extends StatelessWidget {
  final RechazosMastercardState state;
  final RechazosMastercardNotifier notifier;
  const _PanelCompletado({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 24),
              Text(
                '¡Procesamiento completado!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if ((state.rechazosRegistrados ?? 0) > 0)
                Text(
                  '${state.rechazosRegistrados} comprobante(s) RDA creados en CC.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              if ((state.tarjetasActualizadas ?? 0) > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${state.tarjetasActualizadas} tarjeta(s) actualizadas en el sistema.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Procesar otro archivo'),
                onPressed: notifier.reiniciar,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.home),
                label: const Text('Volver al inicio'),
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel: error
// ---------------------------------------------------------------------------

class _PanelError extends StatelessWidget {
  final RechazosMastercardState state;
  final RechazosMastercardNotifier notifier;
  const _PanelError({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text('Error', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                state.error ?? 'Error desconocido',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                onPressed: notifier.reiniciar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget auxiliar
// ---------------------------------------------------------------------------

class _ChipInfo extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  const _ChipInfo(
      {required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 13)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
