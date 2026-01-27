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
final residentesProvider = FutureProvider.family<List<Socio>, ResidentesParams>((ref, params) async {
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

class ListadoResidentesPage extends ConsumerStatefulWidget {
  const ListadoResidentesPage({super.key});

  @override
  ConsumerState<ListadoResidentesPage> createState() => _ListadoResidentesPageState();
}

class _ListadoResidentesPageState extends ConsumerState<ListadoResidentesPage> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  String _searchTerm = '';
  bool _soloActivos = true;

  ResidentesParams get _params => ResidentesParams(soloActivos: _soloActivos);

  void _descargarCSV(List<Socio> residentes) {
    // Crear CSV
    final buffer = StringBuffer();

    // Encabezados
    buffer.writeln('Apellido,Nombre,Inicio Residencia,Fecha Alta,Email,Telefono,Grupo');

    // Datos
    for (final r in residentes) {
      final inicioRes = r.fechaInicioResidencia != null
          ? _dateFormat.format(r.fechaInicioResidencia!)
          : '';
      final fechaAlta = r.fechaIngreso != null
          ? _dateFormat.format(r.fechaIngreso!)
          : '';
      final telefono = r.telefono ?? r.celular ?? '';
      final email = r.email ?? '';
      final grupo = r.grupo ?? '';

      // Escapar campos con comas
      buffer.writeln('"${r.apellido}","${r.nombre}","$inicioRes","$fechaAlta","$email","$telefono","$grupo"');
    }

    // Crear blob y descargar
    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'listado_residentes_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // Botón de descarga
                    residentesAsync.whenOrNull(
                      data: (residentes) {
                        final filtrados = _searchTerm.isEmpty
                            ? residentes
                            : residentes.where((r) {
                                final nombreCompleto = '${r.apellido} ${r.nombre}'.toLowerCase();
                                return nombreCompleto.contains(_searchTerm);
                              }).toList();

                        return FilledButton.icon(
                          onPressed: filtrados.isEmpty ? null : () => _descargarCSV(filtrados),
                          icon: const Icon(Icons.download),
                          label: const Text('Descargar CSV'),
                        );
                      },
                    ) ?? const SizedBox.shrink(),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar por apellido o nombre',
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
                      child: DropdownButtonFormField<bool>(
                        value: _soloActivos,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.filter_list),
                        ),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('Solo Activos')),
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
          // Listado
          Expanded(
            child: residentesAsync.when(
              data: (residentes) {
                // Filtrar por búsqueda
                final filtrados = _searchTerm.isEmpty
                    ? residentes
                    : residentes.where((r) {
                        final nombreCompleto = '${r.apellido} ${r.nombre}'.toLowerCase();
                        return nombreCompleto.contains(_searchTerm);
                      }).toList();

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
                              DataColumn(label: Text('Apellido', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Inicio Residencia', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Fecha Alta', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Teléfono', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Grupo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: filtrados.map((residente) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(residente.apellido)),
                                  DataCell(Text(residente.nombre)),
                                  DataCell(Text(
                                    residente.fechaInicioResidencia != null
                                        ? _dateFormat.format(residente.fechaInicioResidencia!)
                                        : '-',
                                  )),
                                  DataCell(Text(
                                    residente.fechaIngreso != null
                                        ? _dateFormat.format(residente.fechaIngreso!)
                                        : '-',
                                  )),
                                  DataCell(Text(residente.email ?? '-')),
                                  DataCell(Text(residente.telefono ?? residente.celular ?? '-')),
                                  DataCell(Text(residente.grupo ?? '-')),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility, color: Colors.blue),
                                        onPressed: () => context.go('/socios/${residente.id}'),
                                        tooltip: 'Ver ficha',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.account_balance_wallet, color: Colors.green),
                                        onPressed: () => context.go('/socios/${residente.id}/cuenta-corriente'),
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
