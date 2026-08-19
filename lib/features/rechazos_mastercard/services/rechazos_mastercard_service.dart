import 'package:supabase_flutter/supabase_flutter.dart';
import '../../debitos_automaticos/models/presentacion_config.dart';
import '../models/rechazo_mastercard_item.dart';

class RechazosMastercardService {
  final SupabaseClient _supabase;

  RechazosMastercardService(this._supabase);

  /// Cruza cada ítem del archivo con la CC:
  /// - Para rechazos: busca la/s CS original/es que un débito automático
  ///   canceló, agrupando por (entidad, socio, período) porque un DA
  ///   combinado se informa como varias líneas separadas (una por CS).
  ///   O matchean todas las líneas del grupo, o el grupo entero queda sin
  ///   resolver (no se adivina).
  /// - Para observados: solo busca el nombre del socio/profesional.
  Future<List<RechazoMastercardResultado>> buscarDAs(
      List<RechazoMastercardItem> items) async {
    final resultados = <RechazoMastercardResultado>[];

    final observados = items.where((i) => i.esObservado).toList();
    final rechazos = items.where((i) => i.esRechazo).toList();

    for (final item in observados) {
      String? socioNombre;
      try {
        socioNombre = await _buscarNombre(item.entidadId, item.socioId);
      } catch (_) {}
      resultados.add(RechazoMastercardResultado(
        item: item,
        idtransaccionCS: null,
        socioNombre: socioNombre,
        grupoEncontrado: true,
        lineasEnGrupo: 1,
      ));
    }

    final grupos = <String, List<RechazoMastercardItem>>{};
    for (final r in rechazos) {
      grupos.putIfAbsent(r.grupoKey, () => []).add(r);
    }

    for (final entry in grupos.entries) {
      final lineas = entry.value;
      final primero = lineas.first;
      final esSocio = primero.entidadId == 0;
      final idField = esSocio ? 'socio_id' : 'profesional_id';

      String? socioNombre;
      final asignaciones = <RechazoMastercardItem, int>{};

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

        socioNombre = await _buscarNombre(primero.entidadId, primero.socioId);
      } catch (_) {}

      // El grupo solo se considera encontrado si TODAS las líneas matchearon
      final grupoEncontrado = asignaciones.length == lineas.length;

      for (final linea in lineas) {
        resultados.add(RechazoMastercardResultado(
          item: linea,
          idtransaccionCS: grupoEncontrado ? asignaciones[linea] : null,
          socioNombre: socioNombre,
          grupoEncontrado: grupoEncontrado,
          lineasEnGrupo: lineas.length,
          seleccionado: grupoEncontrado,
        ));
      }
    }

    // Preservar el orden original del archivo
    final ordenOriginal = {for (var i = 0; i < items.length; i++) items[i]: i};
    resultados.sort((a, b) =>
        ordenOriginal[a.item]!.compareTo(ordenOriginal[b.item]!));

    return resultados;
  }

  Future<String?> _buscarNombre(int entidadId, int socioId) async {
    if (entidadId == 0) {
      final socioResp = await _supabase
          .from('socios')
          .select('apellido, nombre')
          .eq('id', socioId)
          .maybeSingle();
      if (socioResp == null) return null;
      return '${socioResp['apellido']}, ${socioResp['nombre']}';
    } else {
      final profResp = await _supabase
          .from('profesionales')
          .select('apellido, nombre')
          .eq('id', socioId)
          .maybeSingle();
      if (profResp == null) return null;
      return '${profResp['apellido']}, ${profResp['nombre']}';
    }
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

      final tarjetaNuevaFit = item.tarjetaNueva.length > 16
          ? item.tarjetaNueva.substring(0, 16)
          : item.tarjetaNueva;
      await _supabase
          .from(tabla)
          .update({'numero_tarjeta': tarjetaNuevaFit})
          .eq('id', item.socioId);

      actualizados++;
    }

    return actualizados;
  }

  /// Registra los RDA de forma atómica (todo o nada) para los rechazos
  /// seleccionados, vía la función Postgres registrar_rechazo_debito_automatico.
  /// Retorna la cantidad de registros insertados.
  Future<int> registrarRechazos(
      List<RechazoMastercardResultado> resultados) async {
    final seleccionados = resultados
        .where((r) =>
            r.seleccionado && r.item.esRechazo && r.idtransaccionCS != null)
        .toList();

    if (seleccionados.isEmpty) return 0;

    final payload = seleccionados.map((resultado) {
      final item = resultado.item;
      final fechaStr = item.fechaPresentacion.toIso8601String().split('T')[0];
      return {
        'tarjeta_id': PresentacionConfig.mastercardTarjetaId,
        'periodo': int.parse(item.documentoNumero),
        'socio_id': item.socioId,
        'entidad_id': item.entidadId,
        'importe': item.importe,
        'numero_tarjeta': item.tarjetaActual.length > 16
            ? item.tarjetaActual.substring(0, 16)
            : item.tarjetaActual,
        'motivo':
            item.motivo.length > 16 ? item.motivo.substring(0, 16) : item.motivo,
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
