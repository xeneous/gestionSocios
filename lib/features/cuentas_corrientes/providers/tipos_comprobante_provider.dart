import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tipo_comprobante_socio_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Provider para obtener todos los tipos de comprobante
final tiposComprobanteProvider = FutureProvider<List<TipoComprobanteSocio>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('tipos_comprobante_socios')
      .select('''
        *,
        tipos_movimiento!inner(descripcion)
      ''')
      .order('comprobante', ascending: true);

  return (response as List).map((json) {
    final tipo = TipoComprobanteSocio.fromJson(json);
    if (json['tipos_movimiento'] != null) {
      tipo.tipoMovimientoDescripcion = json['tipos_movimiento']['descripcion'];
    }
    return tipo;
  }).toList();
});

/// Provider para filtrar solo débitos o créditos
final tiposComprobanteDebitoProvider = FutureProvider<List<TipoComprobanteSocio>>((ref) async {
  final todos = await ref.watch(tiposComprobanteProvider.future);
  return todos.where((t) => t.esDebito).toList();
});

final tiposComprobanteCreditoProvider = FutureProvider<List<TipoComprobanteSocio>>((ref) async {
  final todos = await ref.watch(tiposComprobanteProvider.future);
  return todos.where((t) => t.esCredito).toList();
});
