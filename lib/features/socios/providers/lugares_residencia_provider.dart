import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../models/lugar_residencia_model.dart';

/// Provider que obtiene los lugares de residencia activos
final lugaresResidenciaProvider =
    FutureProvider<List<LugarResidencia>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('lugares_residencia')
      .select()
      .eq('activo', true)
      .order('nombre', ascending: true);

  return (response as List)
      .map((json) => LugarResidencia.fromJson(json))
      .toList();
});

/// Agrega un nuevo lugar de residencia y refresca el provider
Future<void> agregarLugarResidencia(String nombre, WidgetRef ref) async {
  final supabase = ref.read(supabaseProvider);
  await supabase.from('lugares_residencia').insert({'nombre': nombre.trim()});
  ref.invalidate(lugaresResidenciaProvider);
}
