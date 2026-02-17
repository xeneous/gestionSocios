import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profesional_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Provider para buscar profesionales con parámetros opcionales
final profesionalesSearchProvider =
    FutureProvider.family<List<ProfesionalModel>, ProfesionalesSearchParams>(
        (ref, params) async {
  final supabase = ref.watch(supabaseProvider);

  var query = supabase.from('profesionales').select();

  // Aplicar filtros si existen
  if (params.profesionalId != null) {
    query = query.eq('id', params.profesionalId!);
  }

  if (params.apellido != null && params.apellido!.isNotEmpty) {
    query = query.ilike('apellido', '%${params.apellido}%');
  }

  if (params.nombre != null && params.nombre!.isNotEmpty) {
    query = query.ilike('nombre', '%${params.nombre}%');
  }

  if (params.numeroDocumento != null && params.numeroDocumento!.isNotEmpty) {
    query = query.ilike('numero_documento', '%${params.numeroDocumento}%');
  }

  if (params.email != null && params.email!.isNotEmpty) {
    query = query.ilike('email', '%${params.email}%');
  }

  // Filtrar solo activos si se especifica
  if (params.soloActivos == true) {
    query = query.eq('activo', true);
  }

  final response = await query
      .order('apellido', ascending: true)
      .limit(50); // Limitar a 50 resultados

  return (response as List)
      .map((json) => ProfesionalModel.fromJson(json))
      .toList();
});

// Clase para parámetros de búsqueda
class ProfesionalesSearchParams {
  final int? profesionalId;
  final String? apellido;
  final String? nombre;
  final String? numeroDocumento;
  final String? email;
  final bool? soloActivos;

  ProfesionalesSearchParams({
    this.profesionalId,
    this.apellido,
    this.nombre,
    this.numeroDocumento,
    this.email,
    this.soloActivos,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfesionalesSearchParams &&
          runtimeType == other.runtimeType &&
          profesionalId == other.profesionalId &&
          apellido == other.apellido &&
          nombre == other.nombre &&
          numeroDocumento == other.numeroDocumento &&
          email == other.email &&
          soloActivos == other.soloActivos;

  @override
  int get hashCode =>
      profesionalId.hashCode ^
      apellido.hashCode ^
      nombre.hashCode ^
      numeroDocumento.hashCode ^
      email.hashCode ^
      soloActivos.hashCode;
}

// Provider para obtener un profesional por ID
final profesionalByIdProvider =
    FutureProvider.family<ProfesionalModel?, int>((ref, profesionalId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('profesionales')
      .select()
      .eq('id', profesionalId)
      .maybeSingle();

  if (response == null) return null;
  return ProfesionalModel.fromJson(response);
});

// Notifier para operaciones CRUD
class ProfesionalesNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<int> createProfesional(ProfesionalModel profesional) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      final response = await supabase
          .from('profesionales')
          .insert(profesional.toJson())
          .select()
          .single();

      state = const AsyncValue.data(null);
      return response['id'] as int;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateProfesional(ProfesionalModel profesional) async {
    if (profesional.id == null) {
      throw Exception('El profesional debe tener un ID para actualizar');
    }

    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase
          .from('profesionales')
          .update(profesional.toJson())
          .eq('id', profesional.id!);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteProfesional(int profesionalId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase.from('profesionales').delete().eq('id', profesionalId);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> darDeBajaProfesional(int profesionalId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase.from('profesionales').update({
        'activo': false,
        'fecha_baja': DateTime.now().toIso8601String(),
      }).eq('id', profesionalId);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> reactivarProfesional(int profesionalId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);

      await supabase.from('profesionales').update({
        'activo': true,
        'fecha_baja': null,
      }).eq('id', profesionalId);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final profesionalesNotifierProvider =
    NotifierProvider<ProfesionalesNotifier, AsyncValue<void>>(
  ProfesionalesNotifier.new,
);

// Notifier para estado de búsqueda
class ProfesionalesSearchStateNotifier
    extends Notifier<ProfesionalesSearchParams> {
  @override
  ProfesionalesSearchParams build() {
    return ProfesionalesSearchParams(soloActivos: true);
  }

  void update(ProfesionalesSearchParams params) {
    state = params;
  }
}

final profesionalesSearchStateProvider =
    NotifierProvider<ProfesionalesSearchStateNotifier,
        ProfesionalesSearchParams>(
  ProfesionalesSearchStateNotifier.new,
);
