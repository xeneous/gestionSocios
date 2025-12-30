import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tipo_movimiento_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Provider para obtener todos los tipos de movimiento
final tiposMovimientoProvider = FutureProvider<List<TipoMovimiento>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('tipos_movimiento')
      .select()
      .order('id', ascending: true);

  return (response as List)
      .map((json) => TipoMovimiento.fromJson(json))
      .toList();
});
