import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cliente_model.dart';
import '../services/clientes_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Provider del servicio
final clientesServiceProvider = Provider<ClientesService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return ClientesService(supabase);
});

// Clase para parámetros de búsqueda
class ClientesSearchParams {
  final int? codigo;
  final String? razonSocial;
  final String? cuit;
  final bool soloActivos;

  ClientesSearchParams({
    this.codigo,
    this.razonSocial,
    this.cuit,
    this.soloActivos = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientesSearchParams &&
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

// Provider para búsqueda de clientes
final clientesSearchProvider =
    FutureProvider.family<List<Cliente>, ClientesSearchParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  var query = supabase.from('clientes').select();

  if (params.codigo != null) {
    query = query.eq('codigo', params.codigo!);
  }

  if (params.razonSocial != null && params.razonSocial!.isNotEmpty) {
    query = query.ilike('razon_social', '%${params.razonSocial!.toUpperCase()}%');
  }

  if (params.cuit != null && params.cuit!.isNotEmpty) {
    query = query.ilike('cuit', '%${params.cuit}%');
  }

  if (params.soloActivos) {
    // Aceptar activo = 1 O activo IS NULL (registros antiguos)
    query = query.or('activo.eq.1,activo.is.null');
  }

  final response = await query
      .order('razon_social', ascending: true)
      .limit(50);

  return (response as List).map((json) => Cliente.fromJson(json)).toList();
});

// Provider para obtener un cliente por código
final clienteProvider = FutureProvider.family<Cliente?, int>((ref, codigo) async {
  final service = ref.watch(clientesServiceProvider);
  return service.getCliente(codigo);
});

// Notifier para operaciones CRUD
class ClientesNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<Cliente> createCliente(Cliente cliente) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(clientesServiceProvider);
      final nuevoCliente = await service.crearCliente(cliente);
      state = const AsyncValue.data(null);
      return nuevoCliente;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<Cliente> updateCliente(Cliente cliente) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(clientesServiceProvider);
      final clienteActualizado = await service.actualizarCliente(cliente);
      state = const AsyncValue.data(null);
      return clienteActualizado;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteCliente(int codigo) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(clientesServiceProvider);
      await service.eliminarCliente(codigo);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> darDeBaja(int codigo) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(clientesServiceProvider);
      await service.darDeBajaCliente(codigo);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> reactivar(int codigo) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(clientesServiceProvider);
      await service.reactivarCliente(codigo);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final clientesNotifierProvider =
    NotifierProvider<ClientesNotifier, AsyncValue<void>>(ClientesNotifier.new);

// Estado de búsqueda persistente para clientes
class ClientesSearchState {
  final String codigo;
  final String razonSocial;
  final String cuit;
  final bool soloActivos;
  final bool hasSearched;
  final List<Cliente> resultados;

  ClientesSearchState({
    this.codigo = '',
    this.razonSocial = '',
    this.cuit = '',
    this.soloActivos = true,
    this.hasSearched = false,
    this.resultados = const [],
  });

  ClientesSearchState copyWith({
    String? codigo,
    String? razonSocial,
    String? cuit,
    bool? soloActivos,
    bool? hasSearched,
    List<Cliente>? resultados,
  }) {
    return ClientesSearchState(
      codigo: codigo ?? this.codigo,
      razonSocial: razonSocial ?? this.razonSocial,
      cuit: cuit ?? this.cuit,
      soloActivos: soloActivos ?? this.soloActivos,
      hasSearched: hasSearched ?? this.hasSearched,
      resultados: resultados ?? this.resultados,
    );
  }

  ClientesSearchParams toSearchParams() {
    return ClientesSearchParams(
      codigo: codigo.isNotEmpty ? int.tryParse(codigo) : null,
      razonSocial: razonSocial.isNotEmpty ? razonSocial : null,
      cuit: cuit.isNotEmpty ? cuit : null,
      soloActivos: soloActivos,
    );
  }

  bool get hasFilters => codigo.isNotEmpty || razonSocial.isNotEmpty || cuit.isNotEmpty;
}

class ClientesSearchStateNotifier extends Notifier<ClientesSearchState> {
  @override
  ClientesSearchState build() {
    return ClientesSearchState();
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

  void setResultados(List<Cliente> clientes) {
    state = state.copyWith(resultados: clientes, hasSearched: true);
  }

  void clearSearch() {
    state = ClientesSearchState();
  }

  void clearResults() {
    state = state.copyWith(resultados: [], hasSearched: false);
  }
}

final clientesSearchStateProvider =
    NotifierProvider<ClientesSearchStateNotifier, ClientesSearchState>(
        ClientesSearchStateNotifier.new);
