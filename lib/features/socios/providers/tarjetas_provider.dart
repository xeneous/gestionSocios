import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tarjeta_model.dart';

class TarjetasNotifier extends AsyncNotifier<List<Tarjeta>> {
  final _supabase = Supabase.instance.client;

  @override
  Future<List<Tarjeta>> build() async {
    return await loadTarjetas();
  }

  Future<List<Tarjeta>> loadTarjetas() async {
    final response = await _supabase
        .from('tarjetas')
        .select()
        .order('descripcion');

    final tarjetas = (response as List)
        .map((json) => Tarjeta.fromJson(json))
        .toList();

    return tarjetas;
  }
  
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadTarjetas());
  }
}

final tarjetasProvider = AsyncNotifierProvider<TarjetasNotifier, List<Tarjeta>>(() {
  return TarjetasNotifier();
});
