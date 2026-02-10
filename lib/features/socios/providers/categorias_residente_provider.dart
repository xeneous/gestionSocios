import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/categoria_residente_model.dart';

class CategoriasResidenteNotifier extends AsyncNotifier<List<CategoriaResidente>> {
  @override
  Future<List<CategoriaResidente>> build() async {
    return await _load();
  }

  Future<List<CategoriaResidente>> _load() async {
    try {
      final response = await Supabase.instance.client
          .from('categorias_residente')
          .select()
          .eq('activo', true)
          .order('orden');

      return (response as List)
          .map((json) => CategoriaResidente.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error cargando categorías de residente: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load());
  }
}

final categoriasResidenteProvider =
    AsyncNotifierProvider<CategoriasResidenteNotifier, List<CategoriaResidente>>(() {
  return CategoriasResidenteNotifier();
});

/// Provider para obtener una categoría específica por código
final categoriaResidenteByCodigoProvider =
    FutureProvider.family<CategoriaResidente?, String>((ref, codigo) async {
  final categorias = await ref.watch(categoriasResidenteProvider.future);
  return categorias.where((c) => c.codigo == codigo).firstOrNull;
});
