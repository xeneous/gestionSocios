import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/debitos_automaticos/models/presentacion_config.dart';
import '../models/rechazo_da_item.dart';

class RechazosDaService {
  final SupabaseClient _supabase;

  RechazosDaService(this._supabase);

  /// Busca en cuentas_corrientes el DA correspondiente a cada rechazo.
  /// Criterio: tipo_comprobante='DA ', entidad_id, socio_id/profesional_id, importe, documento_numero (YYYYMM).
  Future<List<RechazoDAResultado>> buscarDAs(List<RechazoDAItem> rechazos) async {
    final resultados = <RechazoDAResultado>[];

    for (final rechazo in rechazos) {
      String? socioNombre;
      int? idtransaccionDA;

      try {
        // Construir query según entidad
        final esSocio = rechazo.entidadId == 0;
        final idField = esSocio ? 'socio_id' : 'profesional_id';

        final response = await _supabase
            .from('cuentas_corrientes')
            .select('idtransaccion')
            .eq('tipo_comprobante', 'DA ')
            .eq('entidad_id', rechazo.entidadId)
            .eq(idField, rechazo.socioId)
            .eq('documento_numero', rechazo.documentoNumero)
            .eq('importe', rechazo.importe)
            .limit(1);

        if ((response as List).isNotEmpty) {
          idtransaccionDA = response.first['idtransaccion'] as int?;
        }

        // Buscar nombre según entidad
        if (esSocio) {
          final socioResp = await _supabase
              .from('socios')
              .select('apellido, nombre')
              .eq('id', rechazo.socioId)
              .maybeSingle();
          if (socioResp != null) {
            socioNombre = '${socioResp['apellido']}, ${socioResp['nombre']}';
          }
        } else {
          final profResp = await _supabase
              .from('profesionales')
              .select('apellido, nombre')
              .eq('id', rechazo.socioId)
              .maybeSingle();
          if (profResp != null) {
            socioNombre = '${profResp['apellido']}, ${profResp['nombre']}';
          }
        }
      } catch (_) {}

      resultados.add(RechazoDAResultado(
        rechazo: rechazo,
        idtransaccionDA: idtransaccionDA,
        socioNombre: socioNombre,
        seleccionado: idtransaccionDA != null,
      ));
    }

    return resultados;
  }

  /// Registra los RDA en cuentas_corrientes para los resultados seleccionados.
  /// Retorna la cantidad de registros insertados.
  Future<int> registrarRechazos(List<RechazoDAResultado> aprobados) async {
    int insertados = 0;

    for (final resultado in aprobados) {
      if (!resultado.seleccionado || resultado.idtransaccionDA == null) continue;

      final rechazo = resultado.rechazo;
      final esSocio = rechazo.entidadId == 0;
      final fechaStr = rechazo.fechaPresentacion.toIso8601String().split('T')[0];

      await _supabase.from('cuentas_corrientes').insert({
        if (esSocio) 'socio_id': rechazo.socioId,
        if (!esSocio) 'profesional_id': rechazo.socioId,
        'entidad_id': rechazo.entidadId,
        'fecha': fechaStr,
        'tipo_comprobante': 'RDA',
        'documento_numero': rechazo.documentoNumero,
        'importe': rechazo.importe,
        'cancelado': 0.0,
        'vencimiento': fechaStr,
      });

      await _supabase.from('rechazos_tarjetas').insert({
        'tarjeta_id': PresentacionConfig.visaTarjetaId,
        'periodo': int.parse(rechazo.documentoNumero),
        'socio_id': rechazo.socioId,
        'entidad_id': rechazo.entidadId,
        'importe': rechazo.importe,
        'numero_tarjeta': rechazo.tarjeta,
        'motivo': rechazo.motivoCompleto,
        'fecha_rechazo': fechaStr,
      });

      insertados++;
    }

    return insertados;
  }
}
