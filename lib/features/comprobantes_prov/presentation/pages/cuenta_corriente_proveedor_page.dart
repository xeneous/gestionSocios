import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/comprobantes_prov_provider.dart';
import '../../models/comprobante_prov_model.dart';
import '../../services/orden_pago_pdf_service.dart';
import '../../../proveedores/providers/proveedores_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';

/// Página de cuenta corriente de proveedor (A PAGAR)
/// Saldo positivo = debemos al proveedor
class CuentaCorrienteProveedorPage extends ConsumerStatefulWidget {
  final int proveedorId;

  const CuentaCorrienteProveedorPage({
    super.key,
    required this.proveedorId,
  });

  @override
  ConsumerState<CuentaCorrienteProveedorPage> createState() =>
      _CuentaCorrienteProveedorPageState();
}

class _CuentaCorrienteProveedorPageState
    extends ConsumerState<CuentaCorrienteProveedorPage> {
  bool _soloConSaldo = false;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  int _currentPage = 1;
  static const int _pageSize = 100;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  CompProvSearchParams get _searchParams => CompProvSearchParams(
        proveedor: widget.proveedorId,
        soloConSaldo: _soloConSaldo,
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        page: _currentPage,
        pageSize: _pageSize,
      );

  @override
  Widget build(BuildContext context) {
    final proveedorAsync = ref.watch(proveedorProvider(widget.proveedorId));
    final tiposAsync = ref.watch(tiposComprobanteCompraProvider);
    final comprobantesAsync = ref.watch(comprobantesProvSearchProvider(_searchParams));

    // Saldo anterior solo cuando hay fechaDesde
    final saldoAnteriorAsync = _fechaDesde != null
        ? ref.watch(saldoAnteriorProveedorProvider(
            SaldoAnteriorParams(widget.proveedorId, _fechaDesde!)))
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver a Proveedores',
          onPressed: () => context.go('/proveedores'),
        ),
        title: proveedorAsync.when(
          data: (prov) => Text('Cta. Cte. - ${prov?.razonSocial ?? "Proveedor"}'),
          loading: () => const Text('Cuenta Corriente'),
          error: (_, __) => const Text('Cuenta Corriente'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Inicio',
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo Comprobante',
            onPressed: () {
              context.go('/comprobantes-proveedores/nuevo?proveedor=${widget.proveedorId}');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con info del proveedor y saldo
          _buildInfoHeader(proveedorAsync, comprobantesAsync, saldoAnteriorAsync),

          const Divider(height: 1),

          // Filtros
          _buildFiltros(),

          const Divider(height: 1),

          // Tabla de comprobantes
          Expanded(
            child: _buildComprobantesTable(
                comprobantesAsync, tiposAsync, saldoAnteriorAsync),
          ),

          // Paginación (solo cuando no está el filtro soloConSaldo)
          if (!_soloConSaldo) _buildPaginacion(comprobantesAsync),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Solo con saldo
          Checkbox(
            value: _soloConSaldo,
            onChanged: (value) {
              setState(() {
                _soloConSaldo = value ?? false;
                _currentPage = 1;
              });
            },
          ),
          const Text('Solo con saldo pendiente'),
          const SizedBox(width: 16),

          // Fecha desde
          _buildDatePicker(
            label: 'Desde',
            value: _fechaDesde,
            onPicked: (date) {
              setState(() {
                _fechaDesde = date;
                _currentPage = 1;
              });
            },
            onClear: () {
              setState(() {
                _fechaDesde = null;
                _currentPage = 1;
              });
            },
          ),
          const SizedBox(width: 8),

          // Fecha hasta
          _buildDatePicker(
            label: 'Hasta',
            value: _fechaHasta,
            onPicked: (date) {
              setState(() {
                _fechaHasta = date;
                _currentPage = 1;
              });
            },
            onClear: () {
              setState(() {
                _fechaHasta = null;
                _currentPage = 1;
              });
            },
          ),

          const Spacer(),
          Text(
            'A PAGAR',
            style: TextStyle(
              color: Colors.orange[700],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required void Function(DateTime) onPicked,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2099),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              value != null ? '$label: ${_dateFormat.format(value)}' : label,
              style: TextStyle(
                fontSize: 13,
                color: value != null ? Colors.black87 : Colors.grey[600],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClear,
                child: Icon(Icons.close, size: 14, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoHeader(
    AsyncValue proveedorAsync,
    AsyncValue<List<CompProvHeader>> comprobantesAsync,
    AsyncValue<double>? saldoAnteriorAsync,
  ) {
    double totalDeuda = 0;
    double totalPagado = 0;
    int cantidadComprobantes = 0;

    if (comprobantesAsync.hasValue) {
      final comprobantes = comprobantesAsync.value!;
      cantidadComprobantes = comprobantes.length;
      for (final comp in comprobantes) {
        totalDeuda += comp.totalImporte;
        totalPagado += comp.cancelado;
      }
    }

    final saldoPagina = totalDeuda - totalPagado;
    final saldoAnterior = saldoAnteriorAsync?.value ?? 0.0;
    final saldoTotal = saldoAnterior + saldoPagina;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange[50],
      child: Row(
        children: [
          Expanded(
            child: proveedorAsync.when(
              data: (prov) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${prov?.codigo} - ${prov?.razonSocial}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (prov?.cuit != null && prov!.cuit!.isNotEmpty)
                    Text(
                      'CUIT: ${prov.cuit}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                ],
              ),
              loading: () => const Text('Cargando...'),
              error: (_, __) => const Text('Error cargando proveedor'),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Saldo a Pagar: ${_currencyFormat.format(saldoTotal)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: saldoTotal > 0 ? Colors.red : Colors.green,
                ),
              ),
              Text(
                '$cantidadComprobantes comprobante(s) en esta página'
                '${_fechaDesde != null ? ' · Saldo acumulado incluye período anterior' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginacion(AsyncValue<List<CompProvHeader>> comprobantesAsync) {
    final cantidad = comprobantesAsync.value?.length ?? 0;
    final hayAnterior = _currentPage > 1;
    final haySiguiente = cantidad == _pageSize;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: hayAnterior
                ? () => setState(() => _currentPage--)
                : null,
            tooltip: 'Página anterior',
          ),
          Text(
            'Página $_currentPage',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: haySiguiente
                ? () => setState(() => _currentPage++)
                : null,
            tooltip: 'Página siguiente',
          ),
          if (comprobantesAsync.isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildComprobantesTable(
    AsyncValue<List<CompProvHeader>> comprobantesAsync,
    AsyncValue<List<TipoComprobanteCompra>> tiposAsync,
    AsyncValue<double>? saldoAnteriorAsync,
  ) {
    return comprobantesAsync.when(
      data: (comprobantes) {
        if (comprobantes.isEmpty && _currentPage == 1) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _soloConSaldo
                      ? 'No hay comprobantes con saldo pendiente'
                      : 'No hay comprobantes registrados',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final tiposMap = <int, TipoComprobanteCompra>{};
        if (tiposAsync.hasValue) {
          for (final tipo in tiposAsync.value!) {
            tiposMap[tipo.codigo] = tipo;
          }
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 16,
              headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
              columns: const [
                DataColumn(
                    label: Text('Fecha',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Tipo',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Nro. Comprobante',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Debe',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Haber',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Saldo',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Vencimiento',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Acciones',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _buildRows(comprobantes, tiposMap, saldoAnteriorAsync),
            ),
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
          ],
        ),
      ),
    );
  }

  List<DataRow> _buildRows(
    List<CompProvHeader> comprobantes,
    Map<int, TipoComprobanteCompra> tiposMap,
    AsyncValue<double>? saldoAnteriorAsync,
  ) {
    final rows = <DataRow>[];
    final userRole = ref.read(userRoleProvider);

    // Determinar saldo inicial de esta página
    double saldoAcumulado = 0;

    // Si hay saldo anterior (filtro por fecha), lo usamos como punto de partida
    if (saldoAnteriorAsync != null) {
      saldoAcumulado = saldoAnteriorAsync.value ?? 0;
    }

    // Fila de "Saldo Anterior" cuando hay fechaDesde
    if (_fechaDesde != null) {
      final saldoAnterior = saldoAnteriorAsync?.value;
      rows.add(DataRow(
        color: WidgetStateProperty.all(Colors.blue[50]),
        cells: [
          DataCell(Text(
            _dateFormat.format(_fechaDesde!),
            style: const TextStyle(fontStyle: FontStyle.italic),
          )),
          const DataCell(Text('—')),
          DataCell(Text(
            'Saldo anterior al ${_dateFormat.format(_fechaDesde!)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
          )),
          const DataCell(Text('—')),
          const DataCell(Text('—')),
          DataCell(
            saldoAnterior == null
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    _currencyFormat.format(saldoAnterior),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: saldoAnterior > 0 ? Colors.red : Colors.green,
                    ),
                  ),
          ),
          const DataCell(Text('—')),
          const DataCell(Text('')),
        ],
      ));
    }

    // Ordenar por fecha ascendente para calcular saldo acumulado correctamente
    final sorted = List<CompProvHeader>.from(comprobantes)
      ..sort((a, b) {
        final fechaCmp = a.fecha.compareTo(b.fecha);
        if (fechaCmp != 0) return fechaCmp;
        return (a.comprobante).compareTo(b.comprobante);
      });

    for (final comp in sorted) {
      final tipo = tiposMap[comp.tipoComprobante];
      final multiplicador = tipo?.multiplicador ?? 1;

      final importe = _soloConSaldo ? comp.saldo : comp.totalImporte;
      final haber = multiplicador == 1 ? importe : 0.0;
      final debe = multiplicador == -1 ? importe : 0.0;

      saldoAcumulado += haber - debe;

      final isPendiente = comp.saldo > 0;
      final rowColor = isPendiente ? Colors.orange[50] : null;

      final tipoDesc = tipo != null
          ? '${tipo.comprobante} - ${tipo.descripcion}'
          : 'Tipo ${comp.tipoComprobante}';

      rows.add(
        DataRow(
          color: WidgetStateProperty.all(rowColor),
          cells: [
            DataCell(Text(_dateFormat.format(comp.fecha))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tipoDesc),
                  if (comp.tipoFactura != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        comp.tipoFactura!,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            DataCell(Text(comp.nroComprobante)),
            DataCell(
              Text(
                debe > 0 ? _currencyFormat.format(debe) : '-',
                style: const TextStyle(color: Colors.green),
              ),
            ),
            DataCell(
              Text(
                haber > 0 ? _currencyFormat.format(haber) : '-',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            DataCell(
              Text(
                _currencyFormat.format(saldoAcumulado),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: saldoAcumulado > 0 ? Colors.red : Colors.green,
                ),
              ),
            ),
            DataCell(
              Text(comp.fecha1Venc != null
                  ? _dateFormat.format(comp.fecha1Venc!)
                  : '-'),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility,
                        size: 18, color: Colors.blue),
                    onPressed: () {
                      context.go(
                          '/comprobantes-proveedores/${comp.idTransaccion}');
                    },
                    tooltip: 'Ver Detalle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit,
                        size: 18, color: Colors.orange),
                    onPressed: () {
                      context.go(
                          '/comprobantes-proveedores/${comp.idTransaccion}/editar');
                    },
                    tooltip: 'Editar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (userRole.esAdministrador &&
                      multiplicador == -1 &&
                      comp.idTransaccion != null)
                    IconButton(
                      icon: const Icon(Icons.print,
                          size: 18, color: Colors.teal),
                      onPressed: () => _reimprimirOP(comp),
                      tooltip: 'Reimprimir OP',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return rows;
  }

  Future<void> _reimprimirOP(CompProvHeader comp) async {
    final claveController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reimprimir Orden de Pago'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OP Nro. ${comp.comprobante}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Ingrese la clave de administrador:'),
            const SizedBox(height: 8),
            TextField(
              controller: claveController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Clave',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              onSubmitted: (_) => Navigator.pop(context, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    final claveIngresada = claveController.text;
    claveController.dispose();
    if (confirmed != true) return;

    const adminClave = 'SAO2026';
    if (claveIngresada != adminClave) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clave incorrecta'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generando PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final supabase = ref.read(supabaseProvider);
      final pdfService = OrdenPagoPdfService(supabase);
      final pdf = await pdfService.generarOrdenPagoPdf(
        idTransaccion: comp.idTransaccion!,
      );

      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.print, color: Colors.teal),
              const SizedBox(width: 8),
              Text('OP Nro. ${comp.comprobante}'),
            ],
          ),
          content: const Text('¿Qué desea hacer con la orden de pago?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await pdfService.imprimirOrdenPago(pdf);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              icon: const Icon(Icons.print),
              label: const Text('Imprimir'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final provData =
                      ref.read(proveedorProvider(widget.proveedorId));
                  final nombre = provData.value?.razonSocial ??
                      'proveedor_${widget.proveedorId}';
                  await pdfService.compartirOrdenPago(
                    pdf: pdf,
                    numeroOP: comp.comprobante,
                    nombreProveedor: nombre,
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartir'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
