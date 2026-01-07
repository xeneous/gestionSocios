import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/socio_deuda_item.dart';
import '../../providers/seguimiento_deudas_provider.dart';
import '../../../socios/providers/tarjetas_provider.dart';

class SeguimientoDeudasPage extends ConsumerStatefulWidget {
  const SeguimientoDeudasPage({super.key});

  @override
  ConsumerState<SeguimientoDeudasPage> createState() =>
      _SeguimientoDeudasPageState();
}

class _SeguimientoDeudasPageState extends ConsumerState<SeguimientoDeudasPage> {
  final _mesesImpagosController = TextEditingController(text: '1');
  bool _soloDebitoAutomatico = false;
  int? _tarjetaSeleccionada;
  bool _mostrarResultados = false;
  bool _mesesOMas = true; // Por defecto "o más"
  int _paginaActual = 0;

  @override
  void dispose() {
    _mesesImpagosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tarjetasAsync = ref.watch(tarjetasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de Deudas'),
        actions: [
          if (_mostrarResultados)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _mostrarResultados = false;
                });
              },
              tooltip: 'Nueva búsqueda',
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
                    'Filtros de Búsqueda',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Meses impagos
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _mesesImpagosController,
                                decoration: InputDecoration(
                                  labelText: 'Meses Impagos',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.calendar_month),
                                  helperText: _mesesOMas
                                    ? 'Cantidad mínima de meses adeudados'
                                    : 'Cantidad exacta de meses adeudados',
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 8),
                                Checkbox(
                                  value: _mesesOMas,
                                  onChanged: (value) {
                                    setState(() {
                                      _mesesOMas = value ?? true;
                                    });
                                  },
                                ),
                                const Text(
                                  'o más',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Checkbox Débito Automático
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Solo Débito Automático'),
                          value: _soloDebitoAutomatico,
                          onChanged: (value) {
                            setState(() {
                              _soloDebitoAutomatico = value ?? false;
                              if (!_soloDebitoAutomatico) {
                                _tarjetaSeleccionada = null;
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Selector de tarjeta (solo si débito automático)
                      Expanded(
                        flex: 2,
                        child: _soloDebitoAutomatico
                            ? tarjetasAsync.when(
                                data: (tarjetas) =>
                                    DropdownButtonFormField<int?>(
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
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 16),

                      // Botón Buscar
                      FilledButton.icon(
                        onPressed: _buscar,
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
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

          // Resultados
          Expanded(
            child: _mostrarResultados
                ? _buildResultados()
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
            Icons.search,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Configure los filtros y presione "Buscar"',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Se mostrarán los socios con deudas según los criterios',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    final mesesImpagos = int.tryParse(_mesesImpagosController.text) ?? 1;

    final filtro = FiltroSeguimientoParams(
      mesesImpagos: mesesImpagos,
      soloDebitoAutomatico: _soloDebitoAutomatico,
      tarjetaId: _tarjetaSeleccionada,
      mesesOMas: _mesesOMas,
    );

    final params = FiltroSeguimientoParamsConPaginacion(
      filtro: filtro,
      pagina: _paginaActual,
    );

    final sociosAsync = ref.watch(sociosConDeudaProvider(params));

    return sociosAsync.when(
      data: (data) {
        final socios = data['items'] as List<SocioDeudaItem>;
        final totalCount = data['totalCount'] as int;
        return _buildGrilla(socios, totalCount);
      },
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
                  _mostrarResultados = false;
                });
              },
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrilla(List<SocioDeudaItem> socios, int totalCount) {
    if (socios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron socios con deudas',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'según los criterios de búsqueda',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Column(
      children: [
        // Estadística y paginación info
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, color: Colors.blue, size: 32),
                  const SizedBox(width: 16),
                  Text(
                    '$totalCount socios con deudas encontrados',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Mostrando ${_paginaActual * 50 + 1}-${(_paginaActual * 50 + socios.length).clamp(0, totalCount)} de $totalCount socios',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Grilla
        Expanded(
          child: SingleChildScrollView(
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
                        'Socio',
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
                        'Meses Mora',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Importe',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Acción',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: socios.map((socio) {
                    final tieneEmail = socio.email != null &&
                        socio.email!.isNotEmpty;

                    return DataRow(
                      cells: [
                        DataCell(Text(socio.socioId.toString())),
                        DataCell(Text(socio.apellido)),
                        DataCell(Text(socio.nombre)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getColorMora(socio.mesesMora),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              socio.mesesMora.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            currencyFormat.format(socio.importeTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          tieneEmail
                              ? Text(socio.email!)
                              : Text(
                                  'Sin email',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.email),
                            tooltip: 'Enviar notificación',
                            color: tieneEmail ? Colors.blue : Colors.grey,
                            onPressed: tieneEmail
                                ? () => _enviarNotificacion(socio)
                                : null,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),

        // Controles de paginación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón primera página
              IconButton(
                icon: const Icon(Icons.first_page),
                tooltip: 'Primera página',
                onPressed: _paginaActual > 0
                    ? () {
                        setState(() {
                          _paginaActual = 0;
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 8),

              // Botón anterior
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Página anterior',
                onPressed: _paginaActual > 0
                    ? () {
                        setState(() {
                          _paginaActual--;
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 16),

              // Indicador de página
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Página ${_paginaActual + 1} de ${((totalCount - 1) ~/ 50) + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Botón siguiente
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Página siguiente',
                onPressed: (_paginaActual + 1) * 50 < totalCount
                    ? () {
                        setState(() {
                          _paginaActual++;
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 8),

              // Botón última página
              IconButton(
                icon: const Icon(Icons.last_page),
                tooltip: 'Última página',
                onPressed: (_paginaActual + 1) * 50 < totalCount
                    ? () {
                        setState(() {
                          _paginaActual = ((totalCount - 1) ~/ 50);
                        });
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getColorMora(int mesesMora) {
    if (mesesMora >= 6) return Colors.red;
    if (mesesMora >= 3) return Colors.orange;
    return Colors.yellow.shade700;
  }

  void _buscar() {
    final meses = int.tryParse(_mesesImpagosController.text);
    if (meses == null || meses < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese una cantidad válida de meses'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _mostrarResultados = true;
      _paginaActual = 0; // Reset pagination when searching
    });
  }

  Future<void> _enviarNotificacion(SocioDeudaItem socio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar Notificación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Enviar notificación de deuda a ${socio.apellido}, ${socio.nombre}?'),
            const SizedBox(height: 16),
            Text('Email: ${socio.email}'),
            Text('Meses en mora: ${socio.mesesMora}'),
            Text('Importe total: \$${socio.importeTotal.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
              'Períodos: ${socio.periodosAdeudados}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      final service = ref.read(seguimientoDeudasServiceProvider);
      await service.enviarNotificacion(
        socioId: socio.socioId,
        email: socio.email!,
        deudas: socio.detalles,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificación enviada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar notificación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
