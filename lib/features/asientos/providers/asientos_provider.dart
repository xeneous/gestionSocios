import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/asiento_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Provider para listar asientos
final asientosProvider = FutureProvider<List<AsientoCompleto>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  // Obtener headers
  final headersResponse = await supabase
      .from('asientos_header')
      .select()
      .order('fecha', ascending: false)
      .limit(200);

  final headers = (headersResponse as List)
      .map((json) => AsientoHeader.fromJson(json))
      .toList();

  // Para cada header, obtener sus items
  final asientosCompletos = <AsientoCompleto>[];

  for (final header in headers) {
    final itemsResponse = await supabase
        .from('asientos_items')
        .select('''
          *,
          cuentas!inner(cuenta, descripcion)
        ''')
        .eq('asiento', header.asiento)
        .eq('anio_mes', header.anioMes)
        .eq('tipo_asiento', header.tipoAsiento)
        .order('item');

    final items = (itemsResponse as List).map((json) {
      final item = AsientoItem.fromJson(json);
      // Agregar info de cuenta
      if (json['cuentas'] != null) {
        item.cuentaNumero = json['cuentas']['cuenta'];
        item.cuentaDescripcion = json['cuentas']['descripcion'];
      }
      return item;
    }).toList();

    asientosCompletos.add(AsientoCompleto(
      header: header,
      items: items,
    ));
  }

  return asientosCompletos;
});

// Notifier para operaciones CRUD
class AsientosNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> createAsiento(AsientoCompleto asiento) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      // Validar que esté balanceado
      if (!asiento.isBalanced) {
        throw Exception(
            'El asiento no está balanceado. Debe = ${asiento.totalDebe}, Haber = ${asiento.totalHaber}');
      }

      // Insertar header
      await supabase.from('asientos_header').insert(asiento.header.toJson());

      // Insertar items
      final itemsToInsert = asiento.items.map((item) => item.toJson()).toList();
      if (itemsToInsert.isNotEmpty) {
        await supabase.from('asientos_items').insert(itemsToInsert);
      }

      ref.invalidate(asientosProvider);
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

      ref.invalidate(asientosProvider);
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

      // Actualizar header
      await supabase
          .from('asientos_header')
          .update(asientoCompleto.header.toJson())
          .eq('asiento', asiento)
          .eq('anio_mes', anioMes)
          .eq('tipo_asiento', tipoAsiento);

      // Borrar items viejos (CASCADE los borra automáticamente al borrar header, pero mejor hacerlo explícito)
      await supabase
          .from('asientos_items')
          .delete()
          .eq('asiento', asiento)
          .eq('anio_mes', anioMes)
          .eq('tipo_asiento', tipoAsiento);

      // Insertar items nuevos
      final itemsToInsert =
          asientoCompleto.items.map((item) => item.toJson()).toList();
      if (itemsToInsert.isNotEmpty) {
        await supabase.from('asientos_items').insert(itemsToInsert);
      }

      ref.invalidate(asientosProvider);
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
