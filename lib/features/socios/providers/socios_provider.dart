import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/socio_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Provider para buscar socios con parámetros opcionales
final sociosSearchProvider =
    FutureProvider.family<List<Socio>, SociosSearchParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  var query = supabase.from('socios').select();

  // Aplicar filtros si existen
  if (params.socioId != null) {
    query = query.eq('id', params.socioId!);
  }

  if (params.apellido != null && params.apellido!.isNotEmpty) {
    query = query.ilike('apellido', '%${params.apellido}%');
  }

  if (params.nombre != null && params.nombre!.isNotEmpty) {
    query = query.ilike('nombre', '%${params.nombre}%');
  }

  if (params.email != null && params.email!.isNotEmpty) {
    query = query.ilike('email', '%${params.email}%');
  }

  if (params.grupo != null && params.grupo!.isNotEmpty) {
    query = query.eq('grupo', params.grupo!);
  }

  // Filtrar por grupos activos o todos
  // Si soloActivos = true, filtrar solo socios de grupos activos
  // Se aplica siempre que soloActivos sea true, sin importar si hay otros filtros
  if (params.soloActivos == true) {
    // Solo socios de grupos activos: A, H, T, V
    query = query.inFilter('grupo', ['A', 'H', 'T', 'V']);
  }

  final response = await query
      .order('apellido', ascending: true)
      .limit(12); // Limitar a 12 resultados

  return (response as List).map((json) => Socio.fromJson(json)).toList();
});

// Clase para parámetros de búsqueda
class SociosSearchParams {
  final int? socioId;
  final String? apellido;
  final String? nombre;
  final String? email;
  final String? grupo;
  final bool? soloActivos; // true = solo grupos activos, false/null = todos

  SociosSearchParams({
    this.socioId,
    this.apellido,
    this.nombre,
    this.email,
    this.grupo,
    this.soloActivos,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SociosSearchParams &&
          runtimeType == other.runtimeType &&
          socioId == other.socioId &&
          apellido == other.apellido &&
          nombre == other.nombre &&
          email == other.email &&
          grupo == other.grupo &&
          soloActivos == other.soloActivos;

  @override
  int get hashCode =>
      socioId.hashCode ^
      apellido.hashCode ^
      nombre.hashCode ^
      email.hashCode ^
      grupo.hashCode ^
      soloActivos.hashCode;
}

// Notifier para operaciones CRUD
class SociosNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<int> createSocio(Socio socio) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      // DEBUG: Loguear información del cliente Supabase
      print('DEBUG createSocio: ====================');
      print('DEBUG: Headers Authorization: ${supabase.headers['Authorization']}');
      print('DEBUG: Headers apikey: ${supabase.headers['apikey']}');
      final session = supabase.auth.currentSession;
      if (session != null) {
        print('DEBUG: Tiene sesión activa');
      } else {
        print('DEBUG: NO tiene sesión activa (usando solo apikey)');
      }

      // Remover el campo 'id' del JSON para que PostgreSQL lo genere automáticamente
      final json = socio.toJson();
      json.remove('id');

      print('DEBUG: Insertando socio...');
      print('DEBUG: ====================');

      final response = await supabase
          .from('socios')
          .insert(json)
          .select('id')
          .single();

      print('DEBUG: Socio creado exitosamente con id: ${response['id']}');
      state = const AsyncValue.data(null);
      return response['id'] as int;
    } catch (e, st) {
      print('ERROR createSocio: $e');
      print('ERROR stacktrace: $st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateSocio(int id, Socio socio) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase.from('socios').update(socio.toJson()).eq('id', id);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteSocio(int id) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase.from('socios').delete().eq('id', id);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<Socio?> getSocioById(int id) async {
    try {
      final supabase = ref.read(supabaseProvider);

      final response =
          await supabase.from('socios').select().eq('id', id).single();

      return Socio.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<Socio>> loadMoreSocios(
      SociosSearchParams params, int offset) async {
    final supabase = ref.read(supabaseProvider);

    var query = supabase.from('socios').select();

    // Aplicar mismos filtros
    if (params.apellido != null && params.apellido!.isNotEmpty) {
      query = query.ilike('apellido', '%${params.apellido}%');
    }

    if (params.nombre != null && params.nombre!.isNotEmpty) {
      query = query.ilike('nombre', '%${params.nombre}%');
    }

    if (params.email != null && params.email!.isNotEmpty) {
      query = query.ilike('email', '%${params.email}%');
    }

    if (params.grupo != null && params.grupo!.isNotEmpty) {
      query = query.eq('grupo', params.grupo!);
    }

    if (params.soloActivos == true) {
      query = query.inFilter('grupo', ['A', 'H', 'T', 'V']);
    }

    final response = await query
        .range(offset, offset + 11) // Load 12 more records
        .order('apellido', ascending: true);

    return (response as List).map((json) => Socio.fromJson(json)).toList();
  }
}

final sociosNotifierProvider =
    NotifierProvider<SociosNotifier, AsyncValue<void>>(() {
  return SociosNotifier();
});

// Provider para obtener un socio por ID
final socioByIdProvider = FutureProvider.family<Socio?, int>((ref, id) async {
  return ref.read(sociosNotifierProvider.notifier).getSocioById(id);
});

// ============================================================================
// ESTADO DE BÚSQUEDA PERSISTENTE
// ============================================================================

/// Estado de búsqueda de socios que persiste entre navegaciones
class SociosSearchState {
  final String socioId;
  final String apellido;
  final String nombre;
  final String email;
  final String? grupo;
  final bool soloActivos;
  final bool hasSearched;
  final List<Socio> resultados;
  final bool hasMore;

  const SociosSearchState({
    this.socioId = '',
    this.apellido = '',
    this.nombre = '',
    this.email = '',
    this.grupo,
    this.soloActivos = true,
    this.hasSearched = false,
    this.resultados = const [],
    this.hasMore = true,
  });

  SociosSearchState copyWith({
    String? socioId,
    String? apellido,
    String? nombre,
    String? email,
    String? grupo,
    bool? soloActivos,
    bool? hasSearched,
    List<Socio>? resultados,
    bool? hasMore,
  }) {
    return SociosSearchState(
      socioId: socioId ?? this.socioId,
      apellido: apellido ?? this.apellido,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      grupo: grupo,
      soloActivos: soloActivos ?? this.soloActivos,
      hasSearched: hasSearched ?? this.hasSearched,
      resultados: resultados ?? this.resultados,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  /// Convierte a SociosSearchParams para hacer la búsqueda
  SociosSearchParams toSearchParams() {
    return SociosSearchParams(
      socioId: socioId.isNotEmpty ? int.tryParse(socioId) : null,
      apellido: apellido.isNotEmpty ? apellido : null,
      nombre: nombre.isNotEmpty ? nombre : null,
      email: email.isNotEmpty ? email : null,
      grupo: grupo,
      soloActivos: soloActivos,
    );
  }

  /// Verifica si hay algún filtro activo
  bool get hasFilters =>
      socioId.isNotEmpty ||
      apellido.isNotEmpty ||
      nombre.isNotEmpty ||
      email.isNotEmpty ||
      grupo != null;
}

/// Notifier para manejar el estado de búsqueda de socios
class SociosSearchStateNotifier extends Notifier<SociosSearchState> {
  @override
  SociosSearchState build() {
    return const SociosSearchState();
  }

  void updateSocioId(String value) {
    state = state.copyWith(socioId: value);
  }

  void updateApellido(String value) {
    state = state.copyWith(apellido: value);
  }

  void updateNombre(String value) {
    state = state.copyWith(nombre: value);
  }

  void updateEmail(String value) {
    state = state.copyWith(email: value);
  }

  void updateGrupo(String? value) {
    state = state.copyWith(grupo: value);
  }

  void updateSoloActivos(bool value) {
    state = state.copyWith(soloActivos: value);
  }

  void setResultados(List<Socio> resultados, {bool hasMore = true}) {
    state = state.copyWith(
      resultados: resultados,
      hasSearched: true,
      hasMore: hasMore,
    );
  }

  void addResultados(List<Socio> moreResults, {bool hasMore = true}) {
    state = state.copyWith(
      resultados: [...state.resultados, ...moreResults],
      hasMore: hasMore,
    );
  }

  void clearSearch() {
    state = const SociosSearchState();
  }

  void clearResults() {
    state = state.copyWith(
      resultados: [],
      hasSearched: false,
      hasMore: true,
    );
  }
}

final sociosSearchStateProvider =
    NotifierProvider<SociosSearchStateNotifier, SociosSearchState>(() {
  return SociosSearchStateNotifier();
});
