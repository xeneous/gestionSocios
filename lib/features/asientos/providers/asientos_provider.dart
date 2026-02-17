import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/asiento_model.dart';
import '../services/asientos_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Provider del servicio de asientos
final asientosServiceProvider = Provider<AsientosService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AsientosService(supabase);
});

// Provider para búsqueda de asientos con filtros
final asientosSearchProvider = FutureProvider.family<List<AsientoCompleto>, AsientosSearchParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  // Construir query con filtros
  var query = supabase.from('asientos_header').select();

  // Filtro por fecha desde
  if (params.fechaDesde != null) {
    query = query.gte('fecha', params.fechaDesde!.toIso8601String().substring(0, 10));
  }

  // Filtro por fecha hasta
  if (params.fechaHasta != null) {
    query = query.lte('fecha', params.fechaHasta!.toIso8601String().substring(0, 10));
  }

  // Filtro por tipo de asiento
  if (params.tipoAsiento != null) {
    query = query.eq('tipo_asiento', params.tipoAsiento!);
  }

  // Filtro por número de asiento desde
  if (params.asientoDesde != null) {
    query = query.gte('asiento', params.asientoDesde!);
  }

  // Filtro por número de asiento hasta
  if (params.asientoHasta != null) {
    query = query.lte('asiento', params.asientoHasta!);
  }

  // Ordenar y limitar
  final headersResponse = await query
      .order('fecha', ascending: false)
      .order('asiento', ascending: false)
      .limit(params.limit);

  final headers = (headersResponse as List)
      .map((json) => AsientoHeader.fromJson(json))
      .toList();

  if (headers.isEmpty) return [];

  // Obtener TODOS los items en una sola query (batch) en lugar de N queries
  final asientoNums = headers.map((h) => h.asiento).toSet().toList();

  var itemsQuery = supabase
      .from('asientos_items')
      .select('*, cuentas(cuenta, descripcion)')
      .inFilter('asiento', asientoNums);

  // Si hay filtro de tipo, lo aplica para reducir resultados
  if (params.tipoAsiento != null) {
    itemsQuery = itemsQuery.eq('tipo_asiento', params.tipoAsiento!);
  }

  final itemsAllResponse = await itemsQuery
      .order('asiento')
      .order('item');

  // Agrupar items por clave compuesta (asiento_anioMes_tipoAsiento)
  final itemsByKey = <String, List<AsientoItem>>{};
  for (final json in (itemsAllResponse as List)) {
    final item = AsientoItem.fromJson(json);
    if (json['cuentas'] != null) {
      item.cuentaNumero = json['cuentas']['cuenta'];
      item.cuentaDescripcion = json['cuentas']['descripcion'];
    }
    final key = '${item.asiento}_${item.anioMes}_${item.tipoAsiento}';
    itemsByKey.putIfAbsent(key, () => []).add(item);
  }

  // Armar resultados
  return headers.map((header) {
    final key = '${header.asiento}_${header.anioMes}_${header.tipoAsiento}';
    return AsientoCompleto(
      header: header,
      items: itemsByKey[key] ?? [],
    );
  }).toList();
});

// Clase para parámetros de búsqueda
class AsientosSearchParams {
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final int? tipoAsiento;
  final int? asientoDesde;
  final int? asientoHasta;
  final int limit;

  AsientosSearchParams({
    this.fechaDesde,
    this.fechaHasta,
    this.tipoAsiento,
    this.asientoDesde,
    this.asientoHasta,
    this.limit = 100,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsientosSearchParams &&
          runtimeType == other.runtimeType &&
          fechaDesde == other.fechaDesde &&
          fechaHasta == other.fechaHasta &&
          tipoAsiento == other.tipoAsiento &&
          asientoDesde == other.asientoDesde &&
          asientoHasta == other.asientoHasta &&
          limit == other.limit;

  @override
  int get hashCode =>
      fechaDesde.hashCode ^
      fechaHasta.hashCode ^
      tipoAsiento.hashCode ^
      asientoDesde.hashCode ^
      asientoHasta.hashCode ^
      limit.hashCode;
}

// Notifier para operaciones CRUD
class AsientosNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> createAsiento(AsientoCompleto asiento) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(asientosServiceProvider);

      // Convertir items a AsientoItemData
      final itemsData = asiento.items.map((item) => AsientoItemData(
        cuentaId: item.cuentaId,
        debe: item.debe,
        haber: item.haber,
        observacion: item.observacion,
        centroCosto: item.centroCosto,
      )).toList();

      // Usar el servicio centralizado
      await service.crearAsiento(
        tipoAsiento: asiento.header.tipoAsiento,
        fecha: asiento.header.fecha,
        detalle: asiento.header.detalle ?? '',
        items: itemsData,
        centroCosto: asiento.header.centroCosto,
      );

      // No necesitamos invalidar el provider porque ahora es bajo demanda
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteAsiento(int asiento, int anioMes, int tipoAsiento) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      // El DELETE CASCADE se encarga de borrar los items
      await supabase
          .from('asientos_header')
          .delete()
          .eq('asiento', asiento)
          .eq('anio_mes', anioMes)
          .eq('tipo_asiento', tipoAsiento);

      // No necesitamos invalidar el provider porque ahora es bajo demanda
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<int> getNextAsientoNumber(int anioMes, int tipoAsiento) async {
    try {
      final supabase = ref.read(supabaseProvider);

      final response = await supabase
          .from('asientos_header')
          .select('asiento')
          .eq('anio_mes', anioMes)
          .eq('tipo_asiento', tipoAsiento)
          .order('asiento', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return 1;
      }

      return (response[0]['asiento'] as int) + 1;
    } catch (e) {
      return 1;
    }
  }

  Future<AsientoCompleto?> getAsientoById(
      int asiento, int anioMes, int tipoAsiento) async {
    try {
      final supabase = ref.read(supabaseProvider);

      // Obtener header
      final headerResponse = await supabase
          .from('asientos_header')
          .select()
          .eq('asiento', asiento)
          .eq('anio_mes', anioMes)
          .eq('tipo_asiento', tipoAsiento)
          .single();

      final header = AsientoHeader.fromJson(headerResponse);

      // Obtener items
      final itemsResponse = await supabase
          .from('asientos_items')
          .select('''
            *,
            cuentas!inner(cuenta, descripcion)
          ''')
          .eq('asiento', asiento)
          .eq('anio_mes', anioMes)
          .eq('tipo_asiento', tipoAsiento)
          .order('item');

      final items = (itemsResponse as List).map((json) {
        final item = AsientoItem.fromJson(json);
        if (json['cuentas'] != null) {
          item.cuentaNumero = json['cuentas']['cuenta'];
          item.cuentaDescripcion = json['cuentas']['descripcion'];
        }
        return item;
      }).toList();

      return AsientoCompleto(header: header, items: items);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateAsiento(int asiento, int anioMes, int tipoAsiento,
      AsientoCompleto asientoCompleto) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      // Validar que esté balanceado
      if (!asientoCompleto.isBalanced) {
        throw Exception(
            'El asiento no está balanceado. Debe = ${asientoCompleto.totalDebe}, Haber = ${asientoCompleto.totalHaber}');
      }

      // IMPORTANTE: Borrar items viejos PRIMERO para evitar conflicto de foreign key
      await supabase
          .from('asientos_items')
          .delete()
          .eq('asiento', asiento)
          .eq('anio_mes', anioMes)
          .eq('tipo_asiento', tipoAsiento);

      // Actualizar header DESPUÉS de borrar los items
      await supabase
          .from('asientos_header')
          .update(asientoCompleto.header.toJson())
          .eq('asiento', asiento)
          .eq('anio_mes', anioMes)
          .eq('tipo_asiento', tipoAsiento);

      // Insertar items nuevos
      final itemsToInsert =
          asientoCompleto.items.map((item) => item.toJson()).toList();
      if (itemsToInsert.isNotEmpty) {
        await supabase.from('asientos_items').insert(itemsToInsert);
      }

      // No necesitamos invalidar el provider porque ahora es bajo demanda
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final asientosNotifierProvider =
    NotifierProvider<AsientosNotifier, AsyncValue<void>>(() {
  return AsientosNotifier();
});
