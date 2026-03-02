import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rechazo_historico.dart';

class HistorialRechazosService {
  final SupabaseClient _supabase;

  HistorialRechazosService(this._supabase);

  Future<List<RechazoHistorico>> getRechazos({
    int? tarjetaId,
    int? periodo,
  }) async {
    // Paso 1: obtener rechazos con filtros opcionales
    var query = _supabase.from('rechazos_tarjetas').select();
    if (tarjetaId != null) query = query.eq('tarjeta_id', tarjetaId);
    if (periodo != null) query = query.eq('periodo', periodo);
    final rows =
        ((await query.order('fecha_rechazo', ascending: false)) as List)
            .cast<Map<String, dynamic>>();

    if (rows.isEmpty) return [];

    // Paso 2: batch socios (entidad_id == 0)
    final socioIds = rows
        .where((r) => (r['entidad_id'] as int? ?? 0) == 0)
        .map((r) => r['socio_id'] as int)
        .toSet()
        .toList();
    final sociosMap = <int, Map<String, dynamic>>{};
    if (socioIds.isNotEmpty) {
      final sociosResp = await _supabase
          .from('socios')
          .select('id, apellido, nombre')
          .inFilter('id', socioIds);
      for (final s in sociosResp as List) {
        sociosMap[s['id'] as int] = s as Map<String, dynamic>;
      }
    }

    // Paso 3: batch tarjetas
    final tarjetaIds =
        rows.map((r) => r['tarjeta_id'] as int).toSet().toList();
    final tarjetasResp = await _supabase
        .from('tarjetas')
        .select('id, descripcion')
        .inFilter('id', tarjetaIds);
    final tarjetasMap = <int, String>{};
    for (final t in tarjetasResp as List) {
      tarjetasMap[t['id'] as int] = t['descripcion'] as String;
    }

    return rows
        .map((r) => RechazoHistorico.fromJson(r, sociosMap, tarjetasMap))
        .toList();
  }
}
