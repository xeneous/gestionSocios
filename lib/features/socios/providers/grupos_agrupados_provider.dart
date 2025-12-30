import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../models/grupo_agrupado_model.dart';

// Provider para listar grupos agrupados con filtro opcional de activo
final gruposAgrupadosProvider = FutureProvider.family<List<GrupoAgrupado>, bool?>((ref, soloActivos) async {
  final supabase = ref.watch(supabaseProvider);
  
  var query = supabase
      .from('grupos_agrupados')
      .select();
  
  // Si soloActivos es true, filtrar solo activos
  // Si es false o null, mostrar todos
  if (soloActivos == true) {
    query = query.eq('activo', true);
  }
  
  final response = await query.order('codigo');
  
  return (response as List)
      .map((json) => GrupoAgrupado.fromJson(json))
      .toList();
});
