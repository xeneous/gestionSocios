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

  /// Obtiene el porcentaje de descuento para una categoría de residente
  Future<double> getPorcentajeDescuento(String? categoriaResidente) async {
    if (categoriaResidente == null || categoriaResidente.isEmpty) {
      return 0;
    }

    final response = await _supabase
        .from('categorias_residente')
        .select('porcentaje_descuento')
        .eq('codigo', categoriaResidente)
        .maybeSingle();

    if (response == null) return 0;
    return (response['porcentaje_descuento'] as num).toDouble();
  }

  /// Genera items de cuota social para los próximos N meses
  /// Si es residente, aplica el descuento según la categoría (R1, R2, R3)
  Future<List<CuotaSocialItem>> generarItemsCuota({
    required bool esResidente,
    int cantidadMeses = 3,
    DateTime? fechaInicio,
    String? categoriaResidente,
  }) async {
    final inicio = fechaInicio ?? DateTime.now();
    final items = <CuotaSocialItem>[];

    // Obtener porcentaje de descuento según categoría
    final porcentajeDescuento = esResidente
        ? await getPorcentajeDescuento(categoriaResidente)
        : 0.0;

    for (int i = 0; i < cantidadMeses; i++) {
      final fecha = DateTime(inicio.year, inicio.month + i, 1);
      final anioMes = ValorCuotaSocial.dateToAnioMes(fecha);

      try {
        double valor = await getValorCuota(
          anioMes: anioMes,
          esResidente: esResidente,
        );

        // Aplicar descuento según categoría de residente
        bool tieneDescuento = false;
        if (esResidente && porcentajeDescuento > 0) {
          valor = valor * (100 - porcentajeDescuento) / 100;
          tieneDescuento = porcentajeDescuento > 0;
        }

        items.add(CuotaSocialItem(
          anioMes: anioMes,
          valor: valor,
          incluir: true,
          esPromocion: tieneDescuento,
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
    print('DEBUG crearCuotasSociales: ====================');
    print('DEBUG: socioId = $socioId');
    print('DEBUG: items total = ${items.length}');

    final itemsACrear = items.where((item) => item.incluir && item.valor > 0);
    print('DEBUG: items a crear = ${itemsACrear.length}');

    if (itemsACrear.isEmpty) {
      print('DEBUG: No hay items para crear, retornando');
      return;
    }

    // Crear cada transacción con su detalle
    int contador = 0;
    for (final item in itemsACrear) {
      contador++;
      print('DEBUG: Procesando item $contador - anioMes: ${item.anioMes}, valor: ${item.valor}');

      final fecha = ValorCuotaSocial.anioMesToDate(item.anioMes);
      final primerDia = DateTime(fecha.year, fecha.month, 1);
      final ultimoDia = DateTime(fecha.year, fecha.month + 1, 0);

      // Crear header de la transacción
      final transaccion = {
        'socio_id': socioId,
        'entidad_id': 0, // 0 = Socios
        'fecha': primerDia.toIso8601String(),
        'tipo_comprobante': 'CS',
        'documento_numero': item.anioMes.toString(),
        'importe': item.valor,
        'cancelado': 0,
        'vencimiento': ultimoDia.toIso8601String(),
      };

      print('DEBUG: Insertando transacción: $transaccion');

      try {
        final response = await _supabase
            .from('cuentas_corrientes')
            .insert(transaccion)
            .select('idtransaccion')
            .single();

        final idtransaccion = response['idtransaccion'] as int;
        print('DEBUG: Cuota creada con idtransaccion = $idtransaccion');

        // Crear detalle de la transacción (CRP si es promoción, CS si es normal)
        final detalle = {
          'idtransaccion': idtransaccion,
          'item': 1,
          'concepto': item.concepto,
          'cantidad': 1,
          'importe': item.valor,
        };

        print('DEBUG: Insertando detalle: $detalle');
        await _supabase.from('detalle_cuentas_corrientes').insert(detalle);
        print('DEBUG: Detalle creado exitosamente');
      } catch (e, st) {
        print('ERROR al crear cuota: $e');
        print('ERROR stacktrace: $st');
        rethrow;
      }
    }

    print('DEBUG: Total cuotas creadas: $contador');
    print('DEBUG: ====================');
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
        .eq('tipo_comprobante', 'CS')
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
        .eq('tipo_comprobante', 'CS')
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
