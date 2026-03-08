import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import '../../../../core/utils/web_utils.dart';

import '../../providers/rechazos_da_provider.dart';

class RechazosDaPage extends ConsumerWidget {
  const RechazosDaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechazosDaProvider);
    final notifier = ref.read(rechazosDaProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechazos Débito Automático'),
        actions: [
          if (state.estado != RechazosDaEstado.inicial)
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
            onPressed: () => abrirEnNuevaPestana('/rechazos-da'),
          ),
        ],
      ),
      body: switch (state.estado) {
        RechazosDaEstado.inicial => _PanelSeleccionArchivo(notifier: notifier),
        RechazosDaEstado.buscando =>
          _PanelCargando(mensaje: 'Buscando débitos en cuenta corriente...'),
        RechazosDaEstado.registrando =>
          _PanelCargando(mensaje: 'Registrando rechazos...'),
        RechazosDaEstado.listo =>
          _PanelResultados(state: state, notifier: notifier),
        RechazosDaEstado.completado =>
          _PanelCompletado(state: state, notifier: notifier),
        RechazosDaEstado.error => _PanelError(state: state, notifier: notifier),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Panel: selección de archivo
// ---------------------------------------------------------------------------

class _PanelSeleccionArchivo extends StatelessWidget {
  final RechazosDaNotifier notifier;
  const _PanelSeleccionArchivo({required this.notifier});

  void _seleccionarArchivo() {
    final input = html.FileUploadInputElement();
    input.accept = '.txt';
    input.click();

    input.onChange.listen((event) {
      final file = input.files![0];
      final reader = html.FileReader();
      reader.readAsText(file, 'latin1');
      reader.onLoad.listen((_) {
        final contenido = reader.result as String;
        notifier.procesarArchivo(contenido, file.name);
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
              const Icon(Icons.upload_file, size: 64, color: Colors.blueGrey),
              const SizedBox(height: 24),
              Text(
                'Procesar archivo de rechazos Visa',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Seleccioná el archivo RDEBLIQC recibido de Visa',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Seleccionar archivo .txt'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                onPressed: _seleccionarArchivo,
              ),
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
// Panel: resultados (lista para confirmar)
// ---------------------------------------------------------------------------

class _PanelResultados extends StatelessWidget {
  final RechazosDaState state;
  final RechazosDaNotifier notifier;
  const _PanelResultados({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'es_AR');
    final fmtFecha = DateFormat('dd/MM/yyyy');
    final resultados = state.resultados;

    return Column(
      children: [
        // Resumen
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
                label: 'Rechazos en archivo',
                valor: '${state.totalRechazos}',
                color: Colors.orange,
              ),
              _ChipInfo(
                label: 'DA encontrados',
                valor: '${state.encontrados}',
                color: Colors.green,
              ),
              _ChipInfo(
                label: 'Sin DA en CC',
                valor: '${state.noEncontrados}',
                color: state.noEncontrados > 0 ? Colors.red : Colors.grey,
              ),
              _ChipInfo(
                label: 'Seleccionados',
                valor: '${state.seleccionados}',
                color: Colors.blue,
              ),
            ],
          ),
        ),

        // Barra de acciones
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('Seleccionar todos'),
                onPressed: () => notifier.toggleTodos(true),
              ),
              TextButton.icon(
                icon: const Icon(Icons.deselect, size: 18),
                label: const Text('Deseleccionar todos'),
                onPressed: () => notifier.toggleTodos(false),
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle),
                label: Text('Confirmar ${state.seleccionados} rechazos'),
                onPressed:
                    state.seleccionados == 0 ? null : () => _confirmar(context),
              ),
            ],
          ),
        ),

        // Lista
        if (resultados.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No se encontraron rechazos reales en el archivo.'),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: resultados.length,
              itemBuilder: (context, index) {
                final r = resultados[index];
                final rechazo = r.rechazo;
                final encontrado = r.daEncontrado;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: encontrado ? null : Colors.red.shade50,
                  child: CheckboxListTile(
                    value: r.seleccionado,
                    onChanged: encontrado
                        ? (_) => notifier.toggleSeleccion(index)
                        : null,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.socioNombre ?? 'Socio ${rechazo.socioId}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '\$ ${fmt.format(rechazo.importe)}',
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
                        Row(
                          children: [
                            Text(
                              'Período: ${rechazo.documentoNumero}  •  Presentación: ${fmtFecha.format(rechazo.fechaPresentacion)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Tarjeta: ...${rechazo.tarjeta.length >= 4 ? rechazo.tarjeta.substring(rechazo.tarjeta.length - 4) : rechazo.tarjeta}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
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
                                rechazo.motivoCompleto,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!encontrado)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DA no encontrado en CC',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.red),
                                ),
                              ),
                            if (encontrado)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DA encontrado',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.green),
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

  void _confirmar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar rechazos'),
        content: Text(
          'Se van a crear ${state.seleccionados} comprobante(s) RDA en cuenta corriente. '
          'Esta acción no se puede deshacer. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.confirmarRechazos();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel: completado
// ---------------------------------------------------------------------------

class _PanelCompletado extends StatelessWidget {
  final RechazosDaState state;
  final RechazosDaNotifier notifier;
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
                '¡Rechazos registrados!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Se crearon ${state.registradosCount} comprobante(s) RDA en cuenta corriente.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
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
  final RechazosDaState state;
  final RechazosDaNotifier notifier;
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
