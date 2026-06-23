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
import '../../models/grupo_agrupado_model.dart';
import '../../providers/grupos_agrupados_provider.dart';

/// Socios con derecho a voto: Titulares + Honorarios, más Vitalicios
/// cuya última categoría (antes de pasar a Vitalicio) haya sido Titular u Honorario.
final padronElectoralProvider = FutureProvider<List<Socio>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('socios')
      .select()
      .isFilter('fecha_baja', null)
      .or('grupo.in.(T,H),and(grupo.eq.V,ultima_categoria.in.(T,H))')
      .order('apellido', ascending: true)
      .order('nombre', ascending: true);

  return (response as List).map((json) => Socio.fromJson(json)).toList();
});

class PadronElectoralPage extends ConsumerStatefulWidget {
  const PadronElectoralPage({super.key});

  @override
  ConsumerState<PadronElectoralPage> createState() =>
      _PadronElectoralPageState();
}

class _PadronElectoralPageState extends ConsumerState<PadronElectoralPage> {
  String _searchTerm = '';
  int _rowsPerPage = 25;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(padronElectoralProvider);
    });
  }

  String _descripcionGrupo(String? codigo, List<GrupoAgrupado> grupos) {
    if (codigo == null) return '-';
    final match = grupos.where((g) => g.codigo == codigo);
    return match.isNotEmpty ? match.first.descripcion : codigo;
  }

  List<Socio> _aplicarFiltro(List<Socio> socios) {
    if (_searchTerm.isEmpty) return socios;
    return socios.where((s) {
      final nombreCompleto = '${s.apellido} ${s.nombre}'.toLowerCase();
      final doc = (s.numeroDocumento ?? '').toLowerCase();
      return nombreCompleto.contains(_searchTerm) || doc.contains(_searchTerm);
    }).toList();
  }

  void _exportarExcel(List<Socio> socios, List<GrupoAgrupado> grupos) {
    try {
      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Padron');
      final sheet = excel['Padron'];

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#009688'),
        fontColorHex: ExcelColor.white,
      );

      final headers = [
        'Socio',
        'Apellido',
        'Nombre',
        'Tipo Doc.',
        'N° Documento',
        'Grupo',
        'Categoría Anterior',
        'Domicilio',
        'Localidad',
      ];

      for (var i = 0; i < headers.length; i++) {
        final cell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      for (var i = 0; i < socios.length; i++) {
        final s = socios[i];
        final row = i + 1;

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = IntCellValue(s.id ?? 0);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(s.apellido);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(s.nombre);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = TextCellValue(s.tipoDocumento ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = TextCellValue(s.numeroDocumento ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = TextCellValue(_descripcionGrupo(s.grupo, grupos));
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = TextCellValue(s.grupo == 'V'
                ? _descripcionGrupo(s.ultimaCategoria, grupos)
                : '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = TextCellValue(s.domicilio ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
            .value = TextCellValue(s.localidad ?? '-');
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Error al generar el archivo Excel');
      }

      final timestamp = DateFormat('yyyyMMdd').format(DateTime.now());
      final fileName = 'padron_electoral_$timestamp.xlsx';

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
    final padronAsync = ref.watch(padronElectoralProvider);
    final gruposAsync = ref.watch(gruposAgrupadosProvider(false));

    final grupos = gruposAsync.when(
      data: (data) => data,
      loading: () => <GrupoAgrupado>[],
      error: (_, __) => <GrupoAgrupado>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Padrón Electoral'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(padronElectoralProvider);
              ref.invalidate(gruposAgrupadosProvider);
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
      drawer: AppDrawer(currentRoute: '/padron-electoral'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal[50],
            child: Row(
              children: [
                const Icon(Icons.how_to_vote, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'Socios con derecho a voto',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar por apellido, nombre o documento',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchTerm = value.toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 16),
                padronAsync.whenOrNull(
                      data: (socios) {
                        final filtrados = _aplicarFiltro(socios);
                        return FilledButton.icon(
                          onPressed: filtrados.isEmpty
                              ? null
                              : () => _exportarExcel(filtrados, grupos),
                          icon: const Icon(Icons.download),
                          label: const Text('Excel'),
                        );
                      },
                    ) ??
                    const SizedBox.shrink(),
              ],
            ),
          ),
          Expanded(
            child: padronAsync.when(
              data: (socios) {
                final filtrados = _aplicarFiltro(socios);
                if (filtrados.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No se encontraron socios'),
                      ],
                    ),
                  );
                }
                final source = _PadronDataSource(
                  socios: filtrados,
                  grupos: grupos,
                  descripcionGrupo: _descripcionGrupo,
                  onEdit: (socio) {
                    context.push(
                        '/socios/${socio.id}?returnTo=/padron-electoral');
                  },
                );
                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width < 1000
                          ? 1000
                          : MediaQuery.of(context).size.width - 32,
                      child: PaginatedDataTable(
                        header: Text('${filtrados.length} socio(s) habilitado(s)'),
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
                              label: Text('Documento',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Grupo',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Categoría Anterior',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Acciones',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        source: source,
                        rowsPerPage: _rowsPerPage,
                        availableRowsPerPage: const [25, 50, 100, 300],
                        onRowsPerPageChanged: (value) {
                          setState(() => _rowsPerPage = value ?? 25);
                        },
                      ),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _PadronDataSource extends DataTableSource {
  final List<Socio> socios;
  final List<GrupoAgrupado> grupos;
  final String Function(String?, List<GrupoAgrupado>) descripcionGrupo;
  final void Function(Socio) onEdit;

  _PadronDataSource({
    required this.socios,
    required this.grupos,
    required this.descripcionGrupo,
    required this.onEdit,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= socios.length) return null;
    final socio = socios[index];

    return DataRow(
      cells: [
        DataCell(Text('${socio.id ?? '-'}')),
        DataCell(Text(socio.apellido)),
        DataCell(Text(socio.nombre)),
        DataCell(Text(
            '${socio.tipoDocumento ?? ''} ${socio.numeroDocumento ?? '-'}')),
        DataCell(Text(descripcionGrupo(socio.grupo, grupos))),
        DataCell(Text(socio.grupo == 'V'
            ? descripcionGrupo(socio.ultimaCategoria, grupos)
            : '-')),
        DataCell(
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => onEdit(socio),
            tooltip: 'Editar socio',
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => socios.length;

  @override
  int get selectedRowCount => 0;
}
