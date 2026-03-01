import 'package:supabase_flutter/supabase_flutter.dart';
import '../../debitos_automaticos/models/presentacion_config.dart';
import '../models/rechazo_mastercard_item.dart';

class RechazosMastercardService {
  final SupabaseClient _supabase;

  RechazosMastercardService(this._supabase);

  /// Cruza cada ítem del archivo con la CC:
  /// - Para rechazos: busca el DA correspondiente.
  /// - Para observados: solo busca el nombre del socio/profesional.
  Future<List<RechazoMastercardResultado>> buscarDAs(
      List<RechazoMastercardItem> items) async {
    final resultados = <RechazoMastercardResultado>[];

    for (final item in items) {
      String? socioNombre;
      int? idtransaccionDA;

      try {
        final esSocio = item.entidadId == 0;
        final idField = esSocio ? 'socio_id' : 'profesional_id';

        // Solo buscar DA para rechazos
        if (item.esRechazo) {
          final response = await _supabase
              .from('cuentas_corrientes')
              .select('idtransaccion')
              .eq('tipo_comprobante', 'DA ')
              .eq('entidad_id', item.entidadId)
              .eq(idField, item.socioId)
              .eq('documento_numero', item.documentoNumero)
              .eq('importe', item.importe)
              .limit(1);

          if ((response as List).isNotEmpty) {
            idtransaccionDA = response.first['idtransaccion'] as int?;
          }
        }

        // Buscar nombre del socio/profesional
        if (esSocio) {
          final socioResp = await _supabase
              .from('socios')
              .select('apellido, nombre')
              .eq('id', item.socioId)
              .maybeSingle();
          if (socioResp != null) {
            socioNombre = '${socioResp['apellido']}, ${socioResp['nombre']}';
          }
        } else {
          final profResp = await _supabase
              .from('profesionales')
              .select('apellido, nombre')
              .eq('id', item.socioId)
              .maybeSingle();
          if (profResp != null) {
            socioNombre = '${profResp['apellido']}, ${profResp['nombre']}';
          }
        }
      } catch (_) {}

      resultados.add(RechazoMastercardResultado(
        item: item,
        idtransaccionDA: idtransaccionDA,
        socioNombre: socioNombre,
        seleccionado: item.esObservado || idtransaccionDA != null,
      ));
    }

    return resultados;
  }

  /// Actualiza el número de tarjeta en socios/profesionales para los observados seleccionados.
  /// Retorna la cantidad de registros actualizados.
  Future<int> actualizarTarjetas(
      List<RechazoMastercardResultado> resultados) async {
    int actualizados = 0;

    for (final resultado in resultados) {
      if (!resultado.seleccionado) continue;
      final item = resultado.item;
      if (!item.esObservado) continue;

      final tabla = item.entidadId == 0 ? 'socios' : 'profesionales';

      await _supabase
          .from(tabla)
          .update({'numero_tarjeta': item.tarjetaNueva})
          .eq('id', item.socioId);

      actualizados++;
    }

    return actualizados;
  }

  /// Registra los RDA en cuentas_corrientes para los rechazos seleccionados.
  /// Retorna la cantidad de registros insertados.
  Future<int> registrarRechazos(
      List<RechazoMastercardResultado> resultados) async {
    int insertados = 0;

    for (final resultado in resultados) {
      if (!resultado.seleccionado || resultado.idtransaccionDA == null) continue;
      final item = resultado.item;
      if (!item.esRechazo) continue;

      final esSocio = item.entidadId == 0;
      final fechaStr = item.fechaPresentacion.toIso8601String().split('T')[0];

      await _supabase.from('cuentas_corrientes').insert({
        if (esSocio) 'socio_id': item.socioId,
        if (!esSocio) 'profesional_id': item.socioId,
        'entidad_id': item.entidadId,
        'fecha': fechaStr,
        'tipo_comprobante': 'RDA',
        'documento_numero': item.documentoNumero,
        'importe': item.importe,
        'cancelado': 0.0,
        'vencimiento': fechaStr,
      });

      await _supabase.from('rechazos_tarjetas').insert({
        'tarjeta_id': PresentacionConfig.mastercardTarjetaId,
        'periodo': int.parse(item.documentoNumero),
        'socio_id': item.socioId,
        'entidad_id': item.entidadId,
        'importe': item.importe,
        'numero_tarjeta': item.tarjetaActual,
        'motivo': item.motivo,
        'fecha_rechazo': fechaStr,
      });

      insertados++;
    }

    return insertados;
  }
}
