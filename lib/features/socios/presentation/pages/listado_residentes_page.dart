import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../models/socio_model.dart';

/// Grupos que se consideran activos
const gruposActivos = ['T', 'A', 'V', 'H'];

/// Parámetros para el provider
class ResidentesParams {
  final bool soloActivos;

  ResidentesParams({this.soloActivos = true});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResidentesParams && soloActivos == other.soloActivos;

  @override
  int get hashCode => soloActivos.hashCode;
}

/// Provider para obtener listado de residentes
final residentesProvider =
    FutureProvider.family<List<Socio>, ResidentesParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  var query = supabase
      .from('socios')
      .select()
      .eq('residente', true)
      .isFilter('fecha_baja', null);

  // Si solo activos, filtrar por grupos activos
  if (params.soloActivos) {
    query = query.inFilter('grupo', gruposActivos);
  }

  final response = await query
      .order('apellido', ascending: true)
      .order('nombre', ascending: true);

  return (response as List).map((json) => Socio.fromJson(json)).toList();
});

enum _VistaResidentes { resumen, detalle }

class ListadoResidentesPage extends ConsumerStatefulWidget {
  const ListadoResidentesPage({super.key});

  @override
  ConsumerState<ListadoResidentesPage> createState() =>
      _ListadoResidentesPageState();
}

class _ListadoResidentesPageState extends ConsumerState<ListadoResidentesPage> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  String _searchTerm = '';
  bool _soloActivos = true;
  _VistaResidentes _vista = _VistaResidentes.resumen;
  String? _filtroCategoria; // null = todas

  ResidentesParams get _params => ResidentesParams(soloActivos: _soloActivos);

  List<Socio> _aplicarFiltros(List<Socio> residentes) {
    var filtrados = residentes;

    // Filtrar por categoría
    if (_filtroCategoria != null) {
      filtrados = filtrados
          .where((r) => r.categoriaResidente == _filtroCategoria)
          .toList();
    }

    // Filtrar por búsqueda
    if (_searchTerm.isNotEmpty) {
      filtrados = filtrados.where((r) {
        final nombreCompleto = '${r.apellido} ${r.nombre}'.toLowerCase();
        final lugar = (r.lugarResidencia ?? '').toLowerCase();
        return nombreCompleto.contains(_searchTerm) ||
            lugar.contains(_searchTerm);
      }).toList();
    }

    return filtrados;
  }

  Map<String, int> _contarPorCategoria(List<Socio> residentes) {
    final conteo = <String, int>{
      'R1': 0,
      'R2': 0,
      'R3': 0,
      'Sin categoría': 0,
    };

    for (final r in residentes) {
      final cat = r.categoriaResidente;
      if (cat != null && conteo.containsKey(cat)) {
        conteo[cat] = conteo[cat]! + 1;
      } else {
        conteo['Sin categoría'] = conteo['Sin categoría']! + 1;
      }
    }

    return conteo;
  }

  void _descargarCSV(List<Socio> residentes) {
    final buffer = StringBuffer();

    buffer.writeln(
        'Socio,Apellido,Nombre,Categoría,Lugar Residencia,Inicio Residencia,Fin Residencia,Email,Teléfono,Grupo');

    for (final r in residentes) {
      final inicioRes = r.fechaInicioResidencia != null
          ? _dateFormat.format(r.fechaInicioResidencia!)
          : '';
      final finRes = r.fechaFinResidencia != null
          ? _dateFormat.format(r.fechaFinResidencia!)
          : '';
      final telefono = r.telefono ?? r.celular ?? '';
      final email = r.email ?? '';
      final grupo = r.grupo ?? '';
      final categoria = r.categoriaResidente ?? '';
      final lugar = r.lugarResidencia ?? '';

      buffer.writeln(
          '"${r.id}","${r.apellido}","${r.nombre}","$categoria","$lugar","$inicioRes","$finRes","$email","$telefono","$grupo"');
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download',
          'listado_residentes_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
      ..click();

    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Archivo descargado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final residentesAsync = ref.watch(residentesProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de Residentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(residentesProvider),
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/listado-residentes'),
      body: Column(
        children: [
          // Barra de filtros
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal[50],
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_services, color: Colors.teal),
                    const SizedBox(width: 8),
                    const Text(
                      'Socios Residentes',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // Toggle vista
                    SegmentedButton<_VistaResidentes>(
                      segments: const [
                        ButtonSegment(
                          value: _VistaResidentes.resumen,
                          label: Text('Resumen'),
                          icon: Icon(Icons.pie_chart),
                        ),
                        ButtonSegment(
                          value: _VistaResidentes.detalle,
                          label: Text('Detalle'),
                          icon: Icon(Icons.table_chart),
                        ),
                      ],
                      selected: {_vista},
                      onSelectionChanged: (value) {
                        setState(() => _vista = value.first);
                      },
                    ),
                    const SizedBox(width: 16),
                    // Botón de descarga
                    residentesAsync.whenOrNull(
                          data: (residentes) {
                            final filtrados = _aplicarFiltros(residentes);
                            return FilledButton.icon(
                              onPressed: filtrados.isEmpty
                                  ? null
                                  : () => _descargarCSV(filtrados),
                              icon: const Icon(Icons.download),
                              label: const Text('CSV'),
                            );
                          },
                        ) ??
                        const SizedBox.shrink(),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar por apellido, nombre o lugar',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() => _searchTerm = value.toLowerCase());
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _filtroCategoria,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Todas')),
                          DropdownMenuItem(value: 'R1', child: Text('R1')),
                          DropdownMenuItem(value: 'R2', child: Text('R2')),
                          DropdownMenuItem(value: 'R3', child: Text('R3')),
                        ],
                        onChanged: (value) {
                          setState(() => _filtroCategoria = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        initialValue: _soloActivos,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.filter_list),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: true, child: Text('Solo Activos')),
                          DropdownMenuItem(value: false, child: Text('Todos')),
                        ],
                        onChanged: (value) {
                          setState(() => _soloActivos = value ?? true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Contenido
          Expanded(
            child: residentesAsync.when(
              data: (residentes) {
                if (_vista == _VistaResidentes.resumen) {
                  return _buildResumen(residentes);
                } else {
                  return _buildDetalle(residentes);
                }
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen(List<Socio> residentes) {
    final conteo = _contarPorCategoria(residentes);
    final total = residentes.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total general
          Card(
            color: Colors.teal[700],
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 48),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Residentes',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Text(
                        '$total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Cards por categoría
          Row(
            children: [
              Expanded(
                child: _buildCategoriaCard(
                  'R1',
                  'Residente 1er año',
                  conteo['R1'] ?? 0,
                  total,
                  Colors.blue,
                  Icons.looks_one,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCategoriaCard(
                  'R2',
                  'Residente 2do año',
                  conteo['R2'] ?? 0,
                  total,
                  Colors.orange,
                  Icons.looks_two,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCategoriaCard(
                  'R3',
                  'Residente 3er año',
                  conteo['R3'] ?? 0,
                  total,
                  Colors.green,
                  Icons.looks_3,
                ),
              ),
            ],
          ),
          if ((conteo['Sin categoría'] ?? 0) > 0) ...[
            const SizedBox(height: 16),
            _buildCategoriaCard(
              'S/C',
              'Sin categoría asignada',
              conteo['Sin categoría'] ?? 0,
              total,
              Colors.grey,
              Icons.help_outline,
            ),
          ],
          const SizedBox(height: 32),
          // Tabla resumen
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen por Categoría',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DataTable(
                    columns: const [
                      DataColumn(
                          label: Text('Categoría',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Descripción',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Cantidad',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                      DataColumn(
                          label: Text('%',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                    ],
                    rows: [
                      _buildResumenRow('R1', 'Residente 1er año (100% desc.)',
                          conteo['R1'] ?? 0, total),
                      _buildResumenRow('R2', 'Residente 2do año (100% desc.)',
                          conteo['R2'] ?? 0, total),
                      _buildResumenRow('R3', 'Residente 3er año (0% desc.)',
                          conteo['R3'] ?? 0, total),
                      if ((conteo['Sin categoría'] ?? 0) > 0)
                        _buildResumenRow('S/C', 'Sin categoría',
                            conteo['Sin categoría'] ?? 0, total),
                      DataRow(
                        color: WidgetStateProperty.all(Colors.grey[200]),
                        cells: [
                          const DataCell(Text('',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataCell(Text('TOTAL',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('$total',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                          const DataCell(Text('100%',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaCard(String codigo, String descripcion, int cantidad,
      int total, Color color, IconData icon) {
    final porcentaje = total > 0 ? (cantidad / total * 100) : 0.0;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _filtroCategoria = codigo == 'S/C' ? null : codigo;
            _vista = _VistaResidentes.detalle;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    codigo,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                descripcion,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                '$cantidad',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: porcentaje / 100,
                backgroundColor: Colors.grey[200],
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                '${porcentaje.toStringAsFixed(1)}% del total',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _buildResumenRow(
      String codigo, String descripcion, int cantidad, int total) {
    final porcentaje = total > 0 ? (cantidad / total * 100) : 0.0;
    return DataRow(cells: [
      DataCell(Text(codigo)),
      DataCell(Text(descripcion)),
      DataCell(Text('$cantidad')),
      DataCell(Text('${porcentaje.toStringAsFixed(1)}%')),
    ]);
  }

  Widget _buildDetalle(List<Socio> residentes) {
    final filtrados = _aplicarFiltros(residentes);

    if (filtrados.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No se encontraron residentes'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Contador
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            children: [
              Text('${filtrados.length} residente(s)'),
              const Spacer(),
              if (_soloActivos)
                const Text(
                  'Grupos: T, A, V, H',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
        // Tabla
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 24,
                columns: const [
                  DataColumn(
                      label: Text('Socio',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Apellido',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Nombre',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Categoría',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Lugar Residencia',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Inicio Residencia',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Fin Residencia',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Grupo',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Acciones',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: filtrados.map((residente) {
                  return DataRow(
                    cells: [
                      DataCell(Text('${residente.id ?? '-'}')),
                      DataCell(Text(residente.apellido)),
                      DataCell(Text(residente.nombre)),
                      DataCell(
                        Text(
                          residente.categoriaResidente ?? '-',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _colorCategoria(
                                residente.categoriaResidente),
                          ),
                        ),
                      ),
                      DataCell(Text(residente.lugarResidencia ?? '-')),
                      DataCell(Text(
                        residente.fechaInicioResidencia != null
                            ? _dateFormat
                                .format(residente.fechaInicioResidencia!)
                            : '-',
                      )),
                      DataCell(Text(
                        residente.fechaFinResidencia != null
                            ? _dateFormat
                                .format(residente.fechaFinResidencia!)
                            : '-',
                      )),
                      DataCell(Text(residente.grupo ?? '-')),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility,
                                color: Colors.blue),
                            onPressed: () =>
                                context.go('/socios/${residente.id}'),
                            tooltip: 'Ver ficha',
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_balance_wallet,
                                color: Colors.green),
                            onPressed: () => context.go(
                                '/socios/${residente.id}/cuenta-corriente'),
                            tooltip: 'Cuenta corriente',
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _colorCategoria(String? categoria) {
    switch (categoria) {
      case 'R1':
        return Colors.blue;
      case 'R2':
        return Colors.orange;
      case 'R3':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
