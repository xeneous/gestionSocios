import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/debitos_automaticos/models/presentacion_config.dart';
import '../models/rechazo_da_item.dart';

class RechazosDaService {
  final SupabaseClient _supabase;

  RechazosDaService(this._supabase);

  /// Busca en operaciones_detalle_cuentas_corrientes las CS originales que un
  /// débito automático canceló, para poder matchear rechazos que la tarjeta
  /// informa desglosados por CS (un DA combinado de varias cuotas se reporta
  /// como varias líneas separadas, no como una sola línea con el importe total).
  ///
  /// Agrupa las líneas del archivo por (entidad, socio, período) porque todas
  /// las líneas de un mismo grupo corresponden a un único DA combinado: o
  /// matchean todas, o el grupo entero queda sin resolver (no se adivina).
  Future<List<RechazoDAResultado>> buscarDAs(List<RechazoDAItem> rechazos) async {
    final resultados = <RechazoDAResultado>[];

    final grupos = <String, List<RechazoDAItem>>{};
    for (final r in rechazos) {
      grupos.putIfAbsent(r.grupoKey, () => []).add(r);
    }

    for (final entry in grupos.entries) {
      final lineas = entry.value;
      final primero = lineas.first;
      final esSocio = primero.entidadId == 0;
      final idField = esSocio ? 'socio_id' : 'profesional_id';

      String? socioNombre;
      final asignaciones = <RechazoDAItem, int>{}; // línea -> idtransaccion CS

      try {
        // 1. CS/CRP/CRB de ese socio/período (candidatas a haber sido pagadas por un DA)
        final csDelPeriodo = await _supabase
            .from('cuentas_corrientes')
            .select('idtransaccion')
            .eq(idField, primero.socioId)
            .eq('entidad_id', primero.entidadId)
            .eq('documento_numero', primero.documentoNumero)
            .inFilter('tipo_comprobante', ['CS', 'CRP', 'CRB']);

        final idsCandidatos =
            (csDelPeriodo as List).map((r) => r['idtransaccion'] as int).toList();

        var disponibles = <({int idtransaccion, double monto})>[];

        if (idsCandidatos.isNotEmpty) {
          // 2. De esas CS, cuáles fueron efectivamente canceladas por una
          //    operación de tipo DEBITO_AUTOMATICO (no por un recibo u otro medio)
          final detalles = await _supabase
              .from('operaciones_detalle_cuentas_corrientes')
              .select('idtransaccion, monto, operacion_id')
              .inFilter('idtransaccion', idsCandidatos);

          final operacionIds = (detalles as List)
              .map((d) => d['operacion_id'] as int)
              .toSet()
              .toList();

          final List operacionesDA = operacionIds.isEmpty
              ? []
              : await _supabase
                  .from('operaciones_contables')
                  .select('id')
                  .inFilter('id', operacionIds)
                  .eq('tipo_operacion', 'DEBITO_AUTOMATICO');

          final operacionIdsDA =
              operacionesDA.map((o) => o['id'] as int).toSet();

          disponibles = detalles
              .where((d) => operacionIdsDA.contains(d['operacion_id'] as int))
              .map((d) => (
                    idtransaccion: d['idtransaccion'] as int,
                    monto: (d['monto'] as num).toDouble(),
                  ))
              .toList();
        }

        for (final linea in lineas) {
          final idx = disponibles.indexWhere(
              (c) => (c.monto - linea.importe).abs() < 0.005);
          if (idx != -1) {
            asignaciones[linea] = disponibles[idx].idtransaccion;
            disponibles.removeAt(idx);
          }
        }

        // Buscar nombre según entidad
        if (esSocio) {
          final socioResp = await _supabase
              .from('socios')
              .select('apellido, nombre')
              .eq('id', primero.socioId)
              .maybeSingle();
          if (socioResp != null) {
            socioNombre = '${socioResp['apellido']}, ${socioResp['nombre']}';
          }
        } else {
          final profResp = await _supabase
              .from('profesionales')
              .select('apellido, nombre')
              .eq('id', primero.socioId)
              .maybeSingle();
          if (profResp != null) {
            socioNombre = '${profResp['apellido']}, ${profResp['nombre']}';
          }
        }
      } catch (_) {}

      // El grupo solo se considera encontrado si TODAS las líneas matchearon
      final grupoEncontrado = asignaciones.length == lineas.length;

      for (final linea in lineas) {
        resultados.add(RechazoDAResultado(
          rechazo: linea,
          idtransaccionCS: grupoEncontrado ? asignaciones[linea] : null,
          socioNombre: socioNombre,
          grupoEncontrado: grupoEncontrado,
          lineasEnGrupo: lineas.length,
          seleccionado: grupoEncontrado,
        ));
      }
    }

    // Preservar el orden original del archivo
    final ordenOriginal = {for (var i = 0; i < rechazos.length; i++) rechazos[i]: i};
    resultados.sort((a, b) =>
        ordenOriginal[a.rechazo]!.compareTo(ordenOriginal[b.rechazo]!));

    return resultados;
  }

  /// Registra los RDA de forma atómica (todo o nada) para los resultados
  /// seleccionados, vía la función Postgres registrar_rechazo_debito_automatico.
  /// Retorna la cantidad de registros insertados.
  Future<int> registrarRechazos(List<RechazoDAResultado> aprobados) async {
    final seleccionados = aprobados
        .where((r) => r.seleccionado && r.idtransaccionCS != null)
        .toList();

    if (seleccionados.isEmpty) return 0;

    final payload = seleccionados.map((resultado) {
      final rechazo = resultado.rechazo;
      final fechaStr = rechazo.fechaPresentacion.toIso8601String().split('T')[0];
      return {
        'tarjeta_id': PresentacionConfig.visaTarjetaId,
        'periodo': int.parse(rechazo.documentoNumero),
        'socio_id': rechazo.socioId,
        'entidad_id': rechazo.entidadId,
        'importe': rechazo.importe,
        'numero_tarjeta': rechazo.tarjeta,
        'motivo': rechazo.motivoCompleto,
        'fecha_rechazo': fechaStr,
        'idtransaccion_cs': resultado.idtransaccionCS,
      };
    }).toList();

    final response = await _supabase.rpc(
      'registrar_rechazo_debito_automatico',
      params: {'p_rechazos': payload},
    );

    return (response as Map<String, dynamic>)['insertados'] as int;
  }
}
