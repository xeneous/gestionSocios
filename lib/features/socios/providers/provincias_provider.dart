import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provincia_model.dart';

class ProvinciasNotifier extends AsyncNotifier<List<Provincia>> {
  @override
  Future<List<Provincia>> build() async {
    return await _loadProvincias();
  }

  Future<List<Provincia>> _loadProvincias() async {
    try {
      print('DEBUG: Loading provincias from Supabase...');
      final response = await Supabase.instance.client
          .from('provincias')
          .select('id, descripcion')  // Usar 'id' autoincremental, no 'codigo'
          .order('descripcion');

      print('DEBUG: Provincias response: ${response.length} items');
      final provincias = (response as List)
          .map((json) => Provincia.fromJson(json))
          .toList();
      print('DEBUG: Provincias loaded successfully: ${provincias.length} items');
      return provincias;
    } catch (e) {
      print('DEBUG ERROR loading provincias: $e');
      throw Exception('Error cargando provincias: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadProvincias());
  }
}

final provinciasProvider = AsyncNotifierProvider<ProvinciasNotifier, List<Provincia>>(() {
  return ProvinciasNotifier();
});
