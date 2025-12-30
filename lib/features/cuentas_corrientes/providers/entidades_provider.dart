import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/entidad_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Provider para obtener todas las entidades
final entidadesProvider = FutureProvider<List<Entidad>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('entidades')
      .select()
      .order('id', ascending: true);

  return (response as List)
      .map((json) => Entidad.fromJson(json))
      .toList();
});

/// Provider para obtener entidad por ID
final entidadByIdProvider = FutureProvider.family<Entidad?, int>((ref, id) async {
  final supabase = ref.watch(supabaseProvider);

  try {
    final response = await supabase
        .from('entidades')
        .select()
        .eq('id', id)
        .single();

    return Entidad.fromJson(response);
  } catch (e) {
    return null;
  }
});
