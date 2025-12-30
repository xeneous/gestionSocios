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

  if (params.grupo != null && params.grupo!.isNotEmpty) {
    query = query.eq('grupo', params.grupo!);
  }

  // Filtrar por grupos activos o todos
  // Si soloActivos = true, filtrar solo socios de grupos activos
  // Si soloActivos = false/null, mostrar todos los socios
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
  final String? grupo;
  final bool? soloActivos; // true = solo grupos activos, false/null = todos

  SociosSearchParams({
    this.socioId,
    this.apellido,
    this.nombre,
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
          grupo == other.grupo &&
          soloActivos == other.soloActivos;

  @override
  int get hashCode =>
      socioId.hashCode ^
      apellido.hashCode ^
      nombre.hashCode ^
      grupo.hashCode ^
      soloActivos.hashCode;
}

// Notifier para operaciones CRUD
class SociosNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> createSocio(Socio socio) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase.from('socios').insert(socio.toJson());

      state = const AsyncValue.data(null);
    } catch (e, st) {
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
