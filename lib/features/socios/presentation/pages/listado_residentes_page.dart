import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../models/socio_model.dart';
import '../../models/categoria_residente_model.dart';
import '../../providers/categorias_residente_provider.dart';

/// Grupos que se consideran activos
const gruposActivos = ['T', 'A', 'V', 'H'];

/// Colores e iconos para asignar a cada categoría dinámicamente
const _categoriaColores = [
  Colors.blue,
  Colors.orange,
  Colors.green,
  Colors.purple,
  Colors.teal,
  Colors.red,
];

const _categoriaIconos = [
  Icons.looks_one,
  Icons.looks_two,
  Icons.looks_3,
  Icons.looks_4,
  Icons.looks_5,
  Icons.looks_6,
];

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
  final String? vistaInicial;

  const ListadoResidentesPage({super.key, this.vistaInicial});

  @override
  ConsumerState<ListadoResidentesPage> createState() =>
      _ListadoResidentesPageState();
}

class _ListadoResidentesPageState extends ConsumerState<ListadoResidentesPage> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  String _searchTerm = '';
  bool _soloActivos = true;
  late _VistaResidentes _vista;
  String? _filtroCategoria; // null = todas

  ResidentesParams get _params => ResidentesParams(soloActivos: _soloActivos);

  @override
  void initState() {
    super.initState();
    _vista = widget.vistaInicial == 'detalle'
        ? _VistaResidentes.detalle
        : _VistaResidentes.resumen;
    // Refrescar datos al entrar/volver a la página
    Future.microtask(() {
      ref.invalidate(residentesProvider);
    });
  }

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

  /// Cuenta residentes por categoría, usando las categorías de la BD
  Map<String, int> _contarPorCategoria(
      List<Socio> residentes, List<CategoriaResidente> categorias) {
    final conteo = <String, int>{};

    // Inicializar con todas las categorías de la BD
    for (final cat in categorias) {
      conteo[cat.codigo] = 0;
    }
    conteo['Sin categoría'] = 0;

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

  Color _colorParaIndice(int index) {
    return _categoriaColores[index % _categoriaColores.length];
  }

  IconData _iconoParaIndice(int index) {
    return _categoriaIconos[index % _categoriaIconos.length];
  }

  void _exportarExcel(List<Socio> residentes) {
    try {
      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Residentes');
      final sheet = excel['Residentes'];

      // Estilos
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#009688'),
        fontColorHex: ExcelColor.white,
      );

      // Encabezados
      final headers = [
        'Socio',
        'Apellido',
        'Nombre',
        'Categoría',
        'Lugar Residencia',
        'Inicio Residencia',
        'Fin Residencia',
        'Email',
        'Teléfono',
        'Grupo',
      ];

      for (var i = 0; i < headers.length; i++) {
        final cell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Datos
      for (var i = 0; i < residentes.length; i++) {
        final r = residentes[i];
        final row = i + 1;

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = IntCellValue(r.id ?? 0);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(r.apellido);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(r.nombre);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = TextCellValue(r.categoriaResidente ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = TextCellValue(r.lugarResidencia ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = TextCellValue(r.fechaInicioResidencia != null
                ? _dateFormat.format(r.fechaInicioResidencia!)
                : '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = TextCellValue(r.fechaFinResidencia != null
                ? _dateFormat.format(r.fechaFinResidencia!)
                : '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = TextCellValue(r.email ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
            .value = TextCellValue(r.telefono ?? r.celular ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
            .value = TextCellValue(r.grupo ?? '-');
      }

      // Guardar
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Error al generar el archivo Excel');
      }

      final timestamp = DateFormat('yyyyMMdd').format(DateTime.now());
      final fileName = 'listado_residentes_$timestamp.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exportado: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final residentesAsync = ref.watch(residentesProvider(_params));
    final categoriasAsync = ref.watch(categoriasResidenteProvider);

    // Obtener categorías para el dropdown (puede estar vacío mientras carga)
    final categorias = categoriasAsync.when(
      data: (data) => data,
      loading: () => <CategoriaResidente>[],
      error: (_, __) => <CategoriaResidente>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de Residentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(residentesProvider);
              ref.invalidate(categoriasResidenteProvider);
            },
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
                        ),
                        ButtonSegment(
                          value: _VistaResidentes.detalle,
                          label: Text('Detalle'),
                        ),
                      ],
                      selected: {_vista},
                      onSelectionChanged: (value) {
                        setState(() => _vista = value.first);
                      },
                    ),
                    const SizedBox(width: 16),
                    // Botón de descarga Excel
                    residentesAsync.whenOrNull(
                          data: (residentes) {
                            final filtrados = _aplicarFiltros(residentes);
                            return FilledButton.icon(
                              onPressed: filtrados.isEmpty
                                  ? null
                                  : () => _exportarExcel(filtrados),
                              icon: const Icon(Icons.download),
                              label: const Text('Excel'),
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
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Todas')),
                          ...categorias.map((cat) => DropdownMenuItem(
                              value: cat.codigo, child: Text(cat.codigo))),
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
                  return _buildResumen(residentes, categorias);
                } else {
                  return _buildDetalle(residentes, categorias);
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

  Widget _buildResumen(
      List<Socio> residentes, List<CategoriaResidente> categorias) {
    final conteo = _contarPorCategoria(residentes, categorias);
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
          // Cards por categoría - dinámicas
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (int i = 0; i < categorias.length; i++)
                SizedBox(
                  width: categorias.length <= 3
                      ? (MediaQuery.of(context).size.width - 80) /
                          categorias.length
                      : 250,
                  child: _buildCategoriaCard(
                    categorias[i].codigo,
                    categorias[i].descripcion,
                    conteo[categorias[i].codigo] ?? 0,
                    total,
                    _colorParaIndice(i),
                    _iconoParaIndice(i),
                  ),
                ),
            ],
          ),
          if ((conteo['Sin categoría'] ?? 0) > 0) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              child: _buildCategoriaCard(
                'S/C',
                'Sin categoría asignada',
                conteo['Sin categoría'] ?? 0,
                total,
                Colors.grey,
                Icons.help_outline,
              ),
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
                      for (final cat in categorias)
                        _buildResumenRow(
                          cat.codigo,
                          '${cat.descripcion} (${cat.porcentajeDescuento.toStringAsFixed(0)}% desc.)',
                          conteo[cat.codigo] ?? 0,
                          total,
                        ),
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

  Widget _buildDetalle(
      List<Socio> residentes, List<CategoriaResidente> categorias) {
    final filtrados = _aplicarFiltros(residentes);

    // Mapa de código -> índice para colores
    final catIndexMap = <String, int>{};
    for (int i = 0; i < categorias.length; i++) {
      catIndexMap[categorias[i].codigo] = i;
    }

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
                  final catIdx =
                      catIndexMap[residente.categoriaResidente] ?? -1;
                  final catColor = catIdx >= 0
                      ? _colorParaIndice(catIdx)
                      : Colors.grey;

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
                            color: catColor,
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
                            icon: const Icon(Icons.edit,
                                color: Colors.blue),
                            onPressed: () =>
                                context.go('/socios/${residente.id}?returnTo=/listado-residentes%3Fvista=detalle'),
                            tooltip: 'Editar socio',
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_balance_wallet,
                                color: Colors.green),
                            onPressed: () => context.go(
                                '/socios/${residente.id}/cuenta-corriente?returnTo=/listado-residentes%3Fvista=detalle'),
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
}
