import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pais_model.dart';

class PaisesNotifier extends AsyncNotifier<List<Pais>> {
  @override
  Future<List<Pais>> build() async {
    return await _loadPaises();
  }

  Future<List<Pais>> _loadPaises() async {
    try {
      final response = await Supabase.instance.client
          .from('paises')
          .select('id, nombre')  // Supabase usa 'id' y 'nombre'
          .order('nombre');

      final paises = (response as List)
          .map((json) => Pais.fromJson(json))
          .toList();
      return paises;
    } catch (e) {
      throw Exception('Error cargando países: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPaises());
  }
}

final paisesProvider = AsyncNotifierProvider<PaisesNotifier, List<Pais>>(() {
  return PaisesNotifier();
});
