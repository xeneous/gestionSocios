import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/valor_cuota_social_model.dart';

/// Servicio para manejar cuotas sociales
class CuotaSocialService {
  final SupabaseClient _supabase;

  CuotaSocialService(this._supabase);

  /// Obtiene el valor de cuota social para un período y tipo de socio
  Future<double> getValorCuota({
    required int anioMes,
    required bool esResidente,
  }) async {
    final result = await _supabase.rpc(
      'get_valor_cuota_social',
      params: {
        'p_anio_mes': anioMes,
        'p_es_residente': esResidente,
      },
    );

    return (result as num).toDouble();
  }

  /// Obtiene todos los valores de cuota configurados
  Future<List<ValorCuotaSocial>> getValoresCuota() async {
    final response = await _supabase
        .from('valores_cuota_social')
        .select()
        .order('anio_mes_inicio', ascending: false);

    return (response as List)
        .map((json) => ValorCuotaSocial.fromJson(json))
        .toList();
  }

  /// Genera items de cuota social para los próximos N meses
  Future<List<CuotaSocialItem>> generarItemsCuota({
    required bool esResidente,
    int cantidadMeses = 3,
    DateTime? fechaInicio,
  }) async {
    final inicio = fechaInicio ?? DateTime.now();
    final items = <CuotaSocialItem>[];

    for (int i = 0; i < cantidadMeses; i++) {
      final fecha = DateTime(inicio.year, inicio.month + i, 1);
      final anioMes = ValorCuotaSocial.dateToAnioMes(fecha);

      try {
        final valor = await getValorCuota(
          anioMes: anioMes,
          esResidente: esResidente,
        );

        items.add(CuotaSocialItem(
          anioMes: anioMes,
          valor: valor,
          incluir: true,
        ));
      } catch (e) {
        // Si no hay valor configurado para ese período, usar el último disponible
        // o un valor por defecto
        items.add(CuotaSocialItem(
          anioMes: anioMes,
          valor: 0,
          incluir: false,
        ));
      }
    }

    return items;
  }

  /// Crea transacciones de cuota social en cuentas_corrientes
  Future<void> crearCuotasSociales({
    required int socioId,
    required List<CuotaSocialItem> items,
  }) async {
    final itemsACrear = items.where((item) => item.incluir && item.valor > 0);

    if (itemsACrear.isEmpty) {
      return;
    }

    // Crear cada transacción con su detalle
    for (final item in itemsACrear) {
      final fecha = ValorCuotaSocial.anioMesToDate(item.anioMes);
      final primerDia = DateTime(fecha.year, fecha.month, 1);
      final ultimoDia = DateTime(fecha.year, fecha.month + 1, 0);

      // Crear header de la transacción
      final transaccion = {
        'socio_id': socioId,
        'entidad_id': 0, // 0 = Socios
        'fecha': primerDia.toIso8601String(),
        'tipo_comprobante': 'CS ', // Espacio al final por CHAR(3) en BD
        'documento_numero': item.anioMes.toString(),
        'importe': item.valor,
        'cancelado': 0,
        'vencimiento': ultimoDia.toIso8601String(),
      };

      final response = await _supabase
          .from('cuentas_corrientes')
          .insert(transaccion)
          .select('idtransaccion')
          .single();

      final idtransaccion = response['idtransaccion'] as int;

      // Crear detalle de la transacción
      final detalle = {
        'idtransaccion': idtransaccion,
        'item': 1,
        'concepto': 'CS',
        'cantidad': 1,
        'importe': item.valor,
      };

      await _supabase.from('detalle_cuentas_corrientes').insert(detalle);
    }
  }

  /// Verifica si ya existe una cuota social para un socio y período
  Future<bool> existeCuotaSocial({
    required int socioId,
    required int anioMes,
  }) async {
    final response = await _supabase
        .from('cuentas_corrientes')
        .select('idtransaccion')
        .eq('socio_id', socioId)
        .eq('tipo_comprobante', 'CS ') // Espacio al final por CHAR(3) en BD
        .eq('documento_numero', anioMes.toString())
        .maybeSingle();

    return response != null;
  }

  /// Obtiene las cuotas sociales de un socio
  Future<List<Map<String, dynamic>>> getCuotasSocio(int socioId) async {
    final response = await _supabase
        .from('cuentas_corrientes')
        .select()
        .eq('socio_id', socioId)
        .eq('tipo_comprobante', 'CS ') // Espacio al final por CHAR(3) en BD
        .order('documento_numero', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== CRUD VALORES CUOTA SOCIAL ====================

  /// Crea un nuevo valor de cuota social
  Future<ValorCuotaSocial> crearValorCuota({
    required int anioMesInicio,
    required int? anioMesCierre,
    required double valorResidente,
    required double valorTitular,
  }) async {
    final response = await _supabase
        .from('valores_cuota_social')
        .insert({
          'anio_mes_inicio': anioMesInicio,
          'anio_mes_cierre': anioMesCierre,
          'valor_residente': valorResidente,
          'valor_titular': valorTitular,
        })
        .select()
        .single();

    return ValorCuotaSocial.fromJson(response);
  }

  /// Actualiza un valor de cuota social existente
  Future<ValorCuotaSocial> actualizarValorCuota({
    required int id,
    required int anioMesInicio,
    required int? anioMesCierre,
    required double valorResidente,
    required double valorTitular,
  }) async {
    final response = await _supabase
        .from('valores_cuota_social')
        .update({
          'anio_mes_inicio': anioMesInicio,
          'anio_mes_cierre': anioMesCierre,
          'valor_residente': valorResidente,
          'valor_titular': valorTitular,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return ValorCuotaSocial.fromJson(response);
  }

  /// Elimina un valor de cuota social
  Future<void> eliminarValorCuota(int id) async {
    await _supabase.from('valores_cuota_social').delete().eq('id', id);
  }

  /// Obtiene un valor de cuota social por ID
  Future<ValorCuotaSocial?> getValorCuotaPorId(int id) async {
    final response = await _supabase
        .from('valores_cuota_social')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return ValorCuotaSocial.fromJson(response);
  }
}
