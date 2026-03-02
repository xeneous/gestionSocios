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
      final response = await Supabase.instance.client
          .from('provincias')
          .select('id, descripcion')  // Usar 'id' autoincremental, no 'codigo'
          .order('descripcion');

      final provincias = (response as List)
          .map((json) => Provincia.fromJson(json))
          .toList();
      return provincias;
    } catch (e) {
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
