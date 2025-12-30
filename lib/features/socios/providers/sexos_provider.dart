import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sexo_model.dart';

class SexosNotifier extends AsyncNotifier<List<Sexo>> {
  @override
  Future<List<Sexo>> build() async {
    return await _loadSexos();
  }

  Future<List<Sexo>> _loadSexos() async {
    try {
      final response = await Supabase.instance.client
          .from('sexos')
          .select()
          .order('id');

      return (response as List)
          .map((json) => Sexo.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error cargando sexos: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadSexos());
  }
}

final sexosProvider = AsyncNotifierProvider<SexosNotifier, List<Sexo>>(() {
  return SexosNotifier();
});
