import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/debito_automatico_item.dart';
import '../../providers/debitos_automaticos_provider.dart';
import '../../../socios/providers/tarjetas_provider.dart';

class DebitosAutomaticosPage extends ConsumerStatefulWidget {
  const DebitosAutomaticosPage({super.key});

  @override
  ConsumerState<DebitosAutomaticosPage> createState() =>
      _DebitosAutomaticosPageState();
}

class _DebitosAutomaticosPageState
    extends ConsumerState<DebitosAutomaticosPage> {
  DateTime _fechaSeleccionada = DateTime.now();
  int? _tarjetaSeleccionada;
  bool _mostrarVistaPrevia = false;

  @override
  Widget build(BuildContext context) {
    final tarjetasAsync = ref.watch(tarjetasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentación Débitos Automáticos'),
        actions: [
          if (_mostrarVistaPrevia)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _mostrarVistaPrevia = false;
                });
              },
              tooltip: 'Nueva consulta',
            ),
        ],
      ),
      body: Column(
        children: [
          // Panel de filtros
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtros',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Selector de fecha (mes/año)
                      Expanded(
                        child: InkWell(
                          onTap: () => _seleccionarFecha(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Período',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_month),
                            ),
                            child: Text(
                              DateFormat('MM/yyyy').format(_fechaSeleccionada),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Selector de tarjeta
                      Expanded(
                        flex: 2,
                        child: tarjetasAsync.when(
                          data: (tarjetas) => DropdownButtonFormField<int?>(
                            initialValue: _tarjetaSeleccionada,
                            decoration: const InputDecoration(
                              labelText: 'Tarjeta',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.credit_card),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Todas las tarjetas'),
                              ),
                              ...tarjetas.map(
                                (tarjeta) => DropdownMenuItem<int?>(
                                  value: tarjeta.id,
                                  child: Text(tarjeta.descripcion),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _tarjetaSeleccionada = value;
                              });
                            },
                          ),
                          loading: () => DropdownButtonFormField<int?>(
                            decoration: const InputDecoration(
                              labelText: 'Tarjeta',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.credit_card),
                            ),
                            items: const [],
                            onChanged: null,
                          ),
                          error: (error, _) => TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Tarjeta',
                              border: OutlineInputBorder(),
                              errorText: 'Error al cargar tarjetas',
                              prefixIcon: Icon(Icons.credit_card),
                            ),
                            enabled: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Botón Ver Vista Previa
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _mostrarVistaPrevia = true;
                          });
                        },
                        icon: const Icon(Icons.preview),
                        label: const Text('Ver Vista Previa'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Contenido: Vista previa o mensaje
          Expanded(
            child: _mostrarVistaPrevia
                ? _buildVistaPrevia()
                : _buildMensajeInicial(),
          ),
        ],
      ),
    );
  }

  Widget _buildMensajeInicial() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Seleccione el período y tarjeta',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Luego presione "Ver Vista Previa"',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVistaPrevia() {
    // Calcular anioMes del período seleccionado
    final anioMes = _fechaSeleccionada.year * 100 + _fechaSeleccionada.month;

    // Obtener datos según filtros
    final filtro = FiltroDebitosParams(
      anioMes: anioMes,
      tarjetaId: _tarjetaSeleccionada,
    );

    final movimientosAsync = ref.watch(movimientosPendientesProvider(filtro));
    final estadisticasAsync = ref.watch(estadisticasDebitosProvider(filtro));

    return Column(
      children: [
        // Panel de estadísticas
        estadisticasAsync.when(
          data: (stats) => _buildEstadisticas(stats),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Grilla de datos
        Expanded(
          child: movimientosAsync.when(
            data: (movimientos) => _buildDataTable(movimientos),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _mostrarVistaPrevia = false;
                      });
                    },
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Botón de ejecutar presentación
        movimientosAsync.when(
          data: (movimientos) {
            if (movimientos.isEmpty) return const SizedBox.shrink();

            // Solo mostrar si hay tarjetas válidas
            final tarjetasValidas =
                movimientos.where((m) => m.tarjetaValida).toList();
            if (tarjetasValidas.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'No hay movimientos con tarjetas válidas para procesar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border(
                  top: BorderSide(color: Colors.green.shade200, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tarjetasValidas.length} movimientos listos para procesar',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _ejecutarPresentacion(tarjetasValidas),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Ejecutar Presentación'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildEstadisticas(Map<String, dynamic> stats) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.people,
              label: 'Total Socios',
              value: stats['total_registros'].toString(),
              color: Colors.blue,
            ),
            _buildStatItem(
              icon: Icons.check_circle,
              label: 'Tarjetas Válidas',
              value: stats['tarjetas_validas'].toString(),
              color: Colors.green,
            ),
            _buildStatItem(
              icon: Icons.error,
              label: 'Tarjetas Inválidas',
              value: stats['tarjetas_invalidas'].toString(),
              color: Colors.red,
            ),
            _buildStatItem(
              icon: Icons.attach_money,
              label: 'Total a Debitar',
              value: currencyFormat.format(stats['total_importe']),
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(List<DebitoAutomaticoItem> movimientos) {
    if (movimientos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay movimientos pendientes para el período seleccionado',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            columns: const [
              DataColumn(
                label: Text(
                  'Nº Socio',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Apellido',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Nombre',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Número Tarjeta',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Estado',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Importe',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                numeric: true,
              ),
            ],
            rows: movimientos.map((item) {
              final tarjetaValida = item.tarjetaValida;

              return DataRow(
                cells: [
                  DataCell(Text(item.socioId.toString())),
                  DataCell(Text(item.apellido)),
                  DataCell(Text(item.nombre)),
                  DataCell(
                    Text(
                      item.numeroTarjetaEnmascarado,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: tarjetaValida ? null : Colors.red,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tarjetaValida ? Icons.check_circle : Icons.error,
                          color: tarjetaValida ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tarjetaValida ? 'Válida' : 'Inválida',
                          style: TextStyle(
                            color: tarjetaValida ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      currencyFormat.format(item.importe),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final fechaActual = _fechaSeleccionada;

    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaActual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Seleccionar período',
      fieldLabelText: 'Fecha',
      initialDatePickerMode: DatePickerMode.year,
    );

    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
        _mostrarVistaPrevia = false; // Reset vista previa
      });
    }
  }

  Future<void> _ejecutarPresentacion(
      List<DebitoAutomaticoItem> movimientos) async {
    // Confirmar con el usuario
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Ejecución'),
        content: Text(
          '¿Está seguro que desea procesar ${movimientos.length} débitos automáticos?\n\n'
          'Esta acción generará la presentación para la tarjeta seleccionada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    // TODO: Implementar lógica de ejecución
    // Por ahora mostrar mensaje de éxito
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Presentación ejecutada: ${movimientos.length} movimientos procesados',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Resetear vista
      setState(() {
        _mostrarVistaPrevia = false;
      });
    }
  }
}
