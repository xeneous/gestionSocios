import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/presentacion_tarjeta.dart';

/// Servicio para consultar y actualizar el historial de presentaciones de DA
class HistorialPresentacionesService {
  final SupabaseClient _supabase;

  HistorialPresentacionesService(this._supabase);

  /// Obtiene las cabeceras de presentaciones, opcionalmente filtradas por tarjeta
  Future<List<PresentacionTarjeta>> getPresentaciones({int? tarjetaId}) async {
    // Paso 1: obtener presentaciones (sin join porque no hay FK declarado)
    var query = _supabase.from('presentaciones_tarjetas').select();

    if (tarjetaId != null) {
      query = query.eq('tarjeta_id', tarjetaId);
    }

    final response =
        await query.order('fecha_presentacion', ascending: false);
    final rows = (response as List).cast<Map<String, dynamic>>();

    if (rows.isEmpty) return [];

    // Paso 2: obtener nombres de tarjetas en batch
    final tarjetaIds =
        rows.map((r) => r['tarjeta_id'] as int).toSet().toList();
    final tarjetasResponse = await _supabase
        .from('tarjetas')
        .select('id, descripcion')
        .inFilter('id', tarjetaIds);

    final tarjetasMap = <int, String>{};
    for (final t in tarjetasResponse as List) {
      tarjetasMap[t['id'] as int] = t['descripcion'] as String;
    }

    // Paso 3: construir items con el nombre inyectado
    return rows.map((json) {
      final tid = json['tarjeta_id'] as int;
      final enriched = {
        ...json,
        'tarjetas': {'nombre': tarjetasMap[tid] ?? 'Tarjeta $tid'},
      };
      return PresentacionTarjeta.fromJson(enriched);
    }).toList();
  }

  /// Obtiene el detalle de una presentación por tarjeta + período (YYYYMM)
  Future<List<DetallePresentacion>> getDetalle(
      int tarjetaId, int periodo) async {
    // Paso 1: obtener filas de detalle
    final detalleResponse = await _supabase
        .from('detalle_presentaciones_tarjetas')
        .select()
        .eq('tarjeta_id', tarjetaId)
        .eq('periodo', periodo)
        .order('socio_id');

    final detalleRows =
        (detalleResponse as List).cast<Map<String, dynamic>>();

    if (detalleRows.isEmpty) return [];

    // Paso 2: obtener nombres de socios en batch
    final socioIds =
        detalleRows.map((r) => r['socio_id'] as int).toSet().toList();

    final sociosResponse = await _supabase
        .from('socios')
        .select('id, apellido, nombre')
        .inFilter('id', socioIds);

    final sociosMap = <int, Map<String, dynamic>>{};
    for (final s in sociosResponse as List) {
      sociosMap[s['id'] as int] = s as Map<String, dynamic>;
    }

    // Paso 3: construir items y ordenar por apellido
    final items = detalleRows
        .map((row) => DetallePresentacion.fromJson(row, sociosMap))
        .toList();
    items.sort((a, b) => a.apellido.compareTo(b.apellido));

    return items;
  }

  /// Busca todos los movimientos (cobrados y rechazados) de un número de
  /// tarjeta puntual, a través de todas las presentaciones históricas.
  /// Cruza `detalle_presentaciones_tarjetas` (lo presentado) contra
  /// `rechazos_tarjetas` (lo rechazado por el banco) por socio + período.
  Future<List<DetalleTarjetaBusqueda>> buscarPorNumeroTarjeta(
      String numeroTarjeta) async {
    final detalleResponse = await _supabase
        .from('detalle_presentaciones_tarjetas')
        .select()
        .eq('numero_tarjeta', numeroTarjeta);

    final detalleRows = (detalleResponse as List).cast<Map<String, dynamic>>();
    if (detalleRows.isEmpty) return [];

    final socioIds =
        detalleRows.map((r) => r['socio_id'] as int).toSet().toList();

    final sociosResponse = await _supabase
        .from('socios')
        .select('id, apellido, nombre')
        .inFilter('id', socioIds);
    final sociosMap = <int, Map<String, dynamic>>{
      for (final s in sociosResponse as List) s['id'] as int: s as Map<String, dynamic>,
    };

    final rechazosResponse = await _supabase
        .from('rechazos_tarjetas')
        .select('socio_id, periodo')
        .inFilter('socio_id', socioIds);
    final rechazadosSet = <String>{
      for (final r in rechazosResponse as List)
        '${r['socio_id']}|${r['periodo']}',
    };

    final items = detalleRows.map((row) {
      final socioId = row['socio_id'] as int;
      final periodo = row['periodo'] as int;
      final socio = sociosMap[socioId];
      return DetalleTarjetaBusqueda(
        socioId: socioId,
        apellido: socio?['apellido'] as String? ?? '(Socio $socioId)',
        nombre: socio?['nombre'] as String? ?? '',
        periodo: periodo,
        importe: (row['importe'] as num).toDouble(),
        rechazado: rechazadosSet.contains('$socioId|$periodo'),
      );
    }).toList();

    items.sort((a, b) {
      final apellidoCmp = a.apellido.compareTo(b.apellido);
      if (apellidoCmp != 0) return apellidoCmp;
      return a.periodo.compareTo(b.periodo);
    });

    return items;
  }

  /// Registra la acreditación bancaria de una presentación
  Future<void> actualizarAcreditacion({
    required int id,
    required DateTime fechaAcreditacion,
    required double comision,
    required double neto,
  }) async {
    await _supabase.from('presentaciones_tarjetas').update({
      'fecha_acreditacion':
          fechaAcreditacion.toIso8601String().split('T')[0],
      'comision': comision,
      'neto': neto,
      'procesado': true,
    }).eq('id', id);
  }
}
