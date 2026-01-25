import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proveedor_model.dart';
import '../services/proveedores_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Provider del servicio
final proveedoresServiceProvider = Provider<ProveedoresService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return ProveedoresService(supabase);
});

// Clase para parámetros de búsqueda
class ProveedoresSearchParams {
  final int? codigo;
  final String? razonSocial;
  final String? cuit;
  final bool soloActivos;

  ProveedoresSearchParams({
    this.codigo,
    this.razonSocial,
    this.cuit,
    this.soloActivos = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProveedoresSearchParams &&
          runtimeType == other.runtimeType &&
          codigo == other.codigo &&
          razonSocial == other.razonSocial &&
          cuit == other.cuit &&
          soloActivos == other.soloActivos;

  @override
  int get hashCode =>
      codigo.hashCode ^
      razonSocial.hashCode ^
      cuit.hashCode ^
      soloActivos.hashCode;
}

// Provider para búsqueda de proveedores
final proveedoresSearchProvider =
    FutureProvider.family<List<Proveedor>, ProveedoresSearchParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  var query = supabase.from('proveedores').select();

  if (params.codigo != null) {
    query = query.eq('codigo', params.codigo!);
  }

  if (params.razonSocial != null && params.razonSocial!.isNotEmpty) {
    query = query.ilike('razon_social', '%${params.razonSocial}%');
  }

  if (params.cuit != null && params.cuit!.isNotEmpty) {
    query = query.ilike('cuit', '%${params.cuit}%');
  }

  if (params.soloActivos) {
    query = query.eq('activo', 1).isFilter('fecha_baja', null);
  }

  final response = await query
      .order('razon_social', ascending: true)
      .limit(50);

  return (response as List).map((json) => Proveedor.fromJson(json)).toList();
});

// Provider para obtener un proveedor por código
final proveedorProvider = FutureProvider.family<Proveedor?, int>((ref, codigo) async {
  final service = ref.watch(proveedoresServiceProvider);
  return service.getProveedor(codigo);
});

// Notifier para operaciones CRUD
class ProveedoresNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<Proveedor> createProveedor(Proveedor proveedor) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(proveedoresServiceProvider);
      final nuevoProveedor = await service.crearProveedor(proveedor);
      state = const AsyncValue.data(null);
      return nuevoProveedor;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<Proveedor> updateProveedor(Proveedor proveedor) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(proveedoresServiceProvider);
      final proveedorActualizado = await service.actualizarProveedor(proveedor);
      state = const AsyncValue.data(null);
      return proveedorActualizado;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteProveedor(int codigo) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(proveedoresServiceProvider);
      await service.eliminarProveedor(codigo);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> darDeBaja(int codigo) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(proveedoresServiceProvider);
      await service.darDeBajaProveedor(codigo);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> reactivar(int codigo) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(proveedoresServiceProvider);
      await service.reactivarProveedor(codigo);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final proveedoresNotifierProvider =
    NotifierProvider<ProveedoresNotifier, AsyncValue<void>>(ProveedoresNotifier.new);

// Estado de búsqueda persistente para proveedores
class ProveedoresSearchState {
  final String codigo;
  final String razonSocial;
  final String cuit;
  final bool soloActivos;
  final bool hasSearched;
  final List<Proveedor> resultados;

  ProveedoresSearchState({
    this.codigo = '',
    this.razonSocial = '',
    this.cuit = '',
    this.soloActivos = true,
    this.hasSearched = false,
    this.resultados = const [],
  });

  ProveedoresSearchState copyWith({
    String? codigo,
    String? razonSocial,
    String? cuit,
    bool? soloActivos,
    bool? hasSearched,
    List<Proveedor>? resultados,
  }) {
    return ProveedoresSearchState(
      codigo: codigo ?? this.codigo,
      razonSocial: razonSocial ?? this.razonSocial,
      cuit: cuit ?? this.cuit,
      soloActivos: soloActivos ?? this.soloActivos,
      hasSearched: hasSearched ?? this.hasSearched,
      resultados: resultados ?? this.resultados,
    );
  }

  ProveedoresSearchParams toSearchParams() {
    return ProveedoresSearchParams(
      codigo: codigo.isNotEmpty ? int.tryParse(codigo) : null,
      razonSocial: razonSocial.isNotEmpty ? razonSocial : null,
      cuit: cuit.isNotEmpty ? cuit : null,
      soloActivos: soloActivos,
    );
  }

  bool get hasFilters => codigo.isNotEmpty || razonSocial.isNotEmpty || cuit.isNotEmpty;
}

class ProveedoresSearchStateNotifier extends Notifier<ProveedoresSearchState> {
  @override
  ProveedoresSearchState build() {
    return ProveedoresSearchState();
  }

  void updateCodigo(String value) {
    state = state.copyWith(codigo: value);
  }

  void updateRazonSocial(String value) {
    state = state.copyWith(razonSocial: value);
  }

  void updateCuit(String value) {
    state = state.copyWith(cuit: value);
  }

  void updateSoloActivos(bool value) {
    state = state.copyWith(soloActivos: value);
  }

  void setResultados(List<Proveedor> proveedores) {
    state = state.copyWith(resultados: proveedores, hasSearched: true);
  }

  void clearSearch() {
    state = ProveedoresSearchState();
  }

  void clearResults() {
    state = state.copyWith(resultados: [], hasSearched: false);
  }
}

final proveedoresSearchStateProvider =
    NotifierProvider<ProveedoresSearchStateNotifier, ProveedoresSearchState>(
        ProveedoresSearchStateNotifier.new);
