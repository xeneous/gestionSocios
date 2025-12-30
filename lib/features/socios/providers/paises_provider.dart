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
      print('DEBUG: Loading paises from Supabase...');
      final response = await Supabase.instance.client
          .from('paises')
          .select('id, nombre')  // Supabase usa 'id' y 'nombre'
          .order('nombre');

      print('DEBUG: Paises response: ${response.length} items');
      final paises = (response as List)
          .map((json) => Pais.fromJson(json))
          .toList();
      print('DEBUG: Paises loaded successfully: ${paises.length} items');
      return paises;
    } catch (e) {
      print('DEBUG ERROR loading paises: $e');
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
