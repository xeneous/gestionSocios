import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/web_utils.dart';
import '../../models/presentacion_tarjeta.dart';
import '../../providers/presentaciones_tarjetas_provider.dart';
import '../../../../../core/presentation/widgets/app_drawer.dart';

class PresentacionesTarjetasPage extends ConsumerStatefulWidget {
  const PresentacionesTarjetasPage({super.key});

  @override
  ConsumerState<PresentacionesTarjetasPage> createState() =>
      _PresentacionesTarjetasPageState();
}

class _PresentacionesTarjetasPageState
    extends ConsumerState<PresentacionesTarjetasPage> {
  int? _tarjetaFiltroId; // null = todas
  int _currentPage = 1;
  static const int _pageSize = 12;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    // Siempre cargamos todas las presentaciones; el filtro es client-side
    final presentacionesAsync = ref.watch(presentacionesTarjetasProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentaciones Débito Automático'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Inicio',
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Abrir en nueva pestaña',
            onPressed: () => abrirEnNuevaPestana('/presentaciones-tarjetas'),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/presentaciones-tarjetas'),
      body: presentacionesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error: $e'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.invalidate(presentacionesTarjetasProvider(null)),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (todas) {
          // Derivar tarjetas únicas de los datos cargados
          final tarjetasMap = <int, String>{};
          for (final p in todas) {
            tarjetasMap[p.tarjetaId] = p.nombreTarjeta;
          }

          // Filtrar client-side
          final filtradas = _tarjetaFiltroId == null
              ? todas
              : todas.where((p) => p.tarjetaId == _tarjetaFiltroId).toList();

          final totalPages = (filtradas.length / _pageSize).ceil().clamp(1, 9999);
          final currentPage = _currentPage.clamp(1, totalPages);
          final offset = (currentPage - 1) * _pageSize;
          final presentaciones =
              filtradas.skip(offset).take(_pageSize).toList();

          return Column(
            children: [
              // ── Filtro ────────────────────────────────────────────────
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Text('Tarjeta:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      DropdownButton<int?>(
                        value: _tarjetaFiltroId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todas'),
                          ),
                          ...tarjetasMap.entries.map((e) =>
                              DropdownMenuItem<int?>(
                                value: e.key,
                                child: Text(e.value),
                              )),
                        ],
                        onChanged: (value) => setState(() {
                          _tarjetaFiltroId = value;
                          _currentPage = 1;
                        }),
                      ),
                      const Spacer(),
                      Text(
                        '${filtradas.length} presentaciones',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Actualizar',
                        onPressed: () {
                          setState(() => _currentPage = 1);
                          ref.invalidate(presentacionesTarjetasProvider(null));
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tabla ─────────────────────────────────────────────────
              Expanded(
                child: filtradas.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No hay presentaciones registradas'),
                          ],
                        ),
                      )
                    : _buildTabla(presentaciones),
              ),

              // ── Paginación ────────────────────────────────────────────
              if (filtradas.length > _pageSize)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: currentPage > 1
                            ? () => setState(() => _currentPage = currentPage - 1)
                            : null,
                      ),
                      Text(
                        'Página $currentPage de $totalPages',
                        style: const TextStyle(fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: currentPage < totalPages
                            ? () => setState(() => _currentPage = currentPage + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabla(List<PresentacionTarjeta> presentaciones) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(Colors.purple.shade50),
          columns: const [
            DataColumn(label: Text('Fecha\nPresentación')),
            DataColumn(label: Text('Tarjeta')),
            DataColumn(label: Text('Total'), numeric: true),
            DataColumn(label: Text('Acreditación')),
            DataColumn(label: Text('Comisión'), numeric: true),
            DataColumn(label: Text('Neto'), numeric: true),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: presentaciones.map((p) => _buildRow(p)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(PresentacionTarjeta p) {
    return DataRow(cells: [
      DataCell(Text(_dateFormat.format(p.fechaPresentacion))),
      DataCell(Text(p.nombreTarjeta)),
      DataCell(Text(_currencyFormat.format(p.total))),
      DataCell(Text(p.fechaAcreditacion != null
          ? _dateFormat.format(p.fechaAcreditacion!)
          : '-')),
      DataCell(Text(
          p.comision != null ? _currencyFormat.format(p.comision!) : '-')),
      DataCell(
          Text(p.neto != null ? _currencyFormat.format(p.neto!) : '-')),
      DataCell(_buildEstadoChip(p.procesado)),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: p.procesado ? Colors.grey : Colors.purple,
            ),
            tooltip: 'Registrar acreditación',
            onPressed: () => _mostrarDialogAcreditacion(p),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.blue),
            tooltip: 'Ver detalle',
            onPressed: () => context.go(
              '/presentaciones-tarjetas/detalle',
              extra: p,
            ),
          ),
        ],
      )),
    ]);
  }

  Widget _buildEstadoChip(bool procesado) {
    return Chip(
      label: Text(
        procesado ? 'Procesado' : 'Pendiente',
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: procesado ? Colors.green : Colors.orange,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _mostrarDialogAcreditacion(PresentacionTarjeta presentacion) {
    showDialog(
      context: context,
      builder: (ctx) => _DialogAcreditacion(
        presentacion: presentacion,
        onGuardado: () =>
            ref.invalidate(presentacionesTarjetasProvider(null)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Diálogo de acreditación
// ════════════════════════════════════════════════════════════════════════════

class _DialogAcreditacion extends ConsumerStatefulWidget {
  final PresentacionTarjeta presentacion;
  final VoidCallback onGuardado;

  const _DialogAcreditacion({
    required this.presentacion,
    required this.onGuardado,
  });

  @override
  ConsumerState<_DialogAcreditacion> createState() =>
      _DialogAcreditacionState();
}

class _DialogAcreditacionState extends ConsumerState<_DialogAcreditacion> {
  final _formKey = GlobalKey<FormState>();
  final _comisionController = TextEditingController();
  DateTime? _fechaAcreditacion;
  bool _guardando = false;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    if (widget.presentacion.fechaAcreditacion != null) {
      _fechaAcreditacion = widget.presentacion.fechaAcreditacion;
    }
    if (widget.presentacion.comision != null) {
      _comisionController.text =
          widget.presentacion.comision!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _comisionController.dispose();
    super.dispose();
  }

  double get _comision =>
      double.tryParse(_comisionController.text.replaceAll(',', '.')) ?? 0.0;

  double get _neto => widget.presentacion.total - _comision;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Acreditación – ${widget.presentacion.nombreTarjeta}',
        style: const TextStyle(fontSize: 16),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Presentación: ${_dateFormat.format(widget.presentacion.fechaPresentacion)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Total: ${_currencyFormat.format(widget.presentacion.total)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _seleccionarFecha,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de acreditación *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _fechaAcreditacion != null
                        ? _dateFormat.format(_fechaAcreditacion!)
                        : 'Seleccionar...',
                    style: TextStyle(
                      color: _fechaAcreditacion != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _comisionController,
                decoration: const InputDecoration(
                  labelText: 'Comisión *',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*[.,]?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingrese la comisión';
                  final val =
                      double.tryParse(v.replaceAll(',', '.')) ?? -1;
                  if (val < 0) return 'Valor inválido';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Neto:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      _currencyFormat.format(_neto),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _neto >= 0
                            ? Colors.blue.shade700
                            : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Guardar',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaAcreditacion ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('es', 'AR'),
    );
    if (picked != null) {
      setState(() => _fechaAcreditacion = picked);
    }
  }

  Future<void> _guardar() async {
    if (_fechaAcreditacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Seleccione la fecha de acreditación'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final service = ref.read(historialPresentacionesServiceProvider);
      await service.actualizarAcreditacion(
        id: widget.presentacion.id,
        fechaAcreditacion: _fechaAcreditacion!,
        comision: _comision,
        neto: _neto,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onGuardado();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acreditación registrada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
