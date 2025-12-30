import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cuenta_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Provider para listar las primeras 20 cuentas activas
final cuentasProvider = FutureProvider<List<Cuenta>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('cuentas')
      .select()
      .eq('activo', true)
      .order('descripcion', ascending: true)
      .limit(12);

  return (response as List).map((json) => Cuenta.fromJson(json)).toList();
});

// Provider para buscar cuentas con parámetros
final cuentasSearchProvider =
    FutureProvider.family<List<Cuenta>, CuentasSearchParams>(
        (ref, params) async {
  final supabase = ref.read(supabaseProvider);

  var query = supabase.from('cuentas').select().eq('activo', true);

  if (params.searchTerm != null && params.searchTerm!.isNotEmpty) {
    // Buscar por número de cuenta o descripción
    final searchTerm = params.searchTerm!;

    // Intentar parsear como número para búsqueda exacta por cuenta
    final cuentaNumero = int.tryParse(searchTerm);

    if (cuentaNumero != null) {
      // Si es un número, buscar por número de cuenta exacto o por descripción
      query =
          query.or('cuenta.eq.$cuentaNumero,descripcion.ilike.%$searchTerm%');
    } else {
      // Si no es un número, solo buscar en descripción
      query = query.ilike('descripcion', '%$searchTerm%');
    }
  }

  final response = await query.order('descripcion', ascending: true).limit(12);

  return (response as List).map((json) => Cuenta.fromJson(json)).toList();
});

// Clase para parámetros de búsqueda de cuentas
class CuentasSearchParams {
  final String? searchTerm;

  CuentasSearchParams({this.searchTerm});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CuentasSearchParams &&
          runtimeType == other.runtimeType &&
          searchTerm == other.searchTerm;

  @override
  int get hashCode => searchTerm.hashCode;
}

// Notifier para mantener el estado de búsqueda actual
class CuentasSearchStateNotifier extends Notifier<CuentasSearchParams?> {
  @override
  CuentasSearchParams? build() => null;

  void setSearch(CuentasSearchParams? params) {
    state = params;
  }

  void clearSearch() {
    state = null;
  }
}

final cuentasSearchStateProvider =
    NotifierProvider<CuentasSearchStateNotifier, CuentasSearchParams?>(() {
  return CuentasSearchStateNotifier();
});

// Notifier para operaciones CRUD
class CuentasNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> createCuenta(Cuenta cuenta) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('cuentas').insert(cuenta.toJson());

      // Invalidar todos los providers de cuentas para refrescar datos
      ref.invalidate(cuentasProvider);
      ref.invalidate(cuentasSearchProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateCuenta(int cuentaNumero, Cuenta cuenta) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('cuentas')
          .update(cuenta.toJson())
          .eq('cuenta', cuentaNumero);

      // Invalidar todos los providers de cuentas para refrescar datos
      ref.invalidate(cuentasProvider);
      ref.invalidate(cuentasSearchProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteCuenta(int cuentaNumero) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);
      // Soft delete - marcar como inactivo
      await supabase
          .from('cuentas')
          .update({'activo': false}).eq('cuenta', cuentaNumero);

      // Invalidar todos los providers de cuentas para refrescar datos
      ref.invalidate(cuentasProvider);
      ref.invalidate(cuentasSearchProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<Cuenta?> getCuentaByCuenta(int cuentaNumero) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('cuentas')
          .select()
          .eq('cuenta', cuentaNumero)
          .single();

      return Cuenta.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<Cuenta>> loadMoreCuentas(
      CuentasSearchParams params, int offset) async {
    final supabase = ref.read(supabaseProvider);

    var query = supabase.from('cuentas').select().eq('activo', true);

    if (params.searchTerm != null && params.searchTerm!.isNotEmpty) {
      final searchTerm = params.searchTerm!;
      final cuentaNumero = int.tryParse(searchTerm);

      if (cuentaNumero != null) {
        query =
            query.or('cuenta.eq.$cuentaNumero,descripcion.ilike.%$searchTerm%');
      } else {
        query = query.ilike('descripcion', '%$searchTerm%');
      }
    }

    final response = await query
        .range(offset, offset + 11) // Load 12 more records
        .order('descripcion', ascending: true);

    return (response as List).map((json) => Cuenta.fromJson(json)).toList();
  }
}

final cuentasNotifierProvider =
    NotifierProvider<CuentasNotifier, AsyncValue<void>>(() {
  return CuentasNotifier();
});
