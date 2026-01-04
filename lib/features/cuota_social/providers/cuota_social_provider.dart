import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cuota_social_service.dart';
import '../models/valor_cuota_social_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Provider del servicio de cuota social
final cuotaSocialServiceProvider = Provider<CuotaSocialService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return CuotaSocialService(supabase);
});

/// Provider para obtener valores de cuota configurados
final valoresCuotaProvider = FutureProvider<List<ValorCuotaSocial>>((ref) async {
  final service = ref.watch(cuotaSocialServiceProvider);
  return service.getValoresCuota();
});

/// Provider para generar items de cuota (usado en el diálogo)
final itemsCuotaProvider = FutureProvider.family<List<CuotaSocialItem>, ItemsCuotaParams>(
  (ref, params) async {
    final service = ref.watch(cuotaSocialServiceProvider);
    return service.generarItemsCuota(
      esResidente: params.esResidente,
      cantidadMeses: params.cantidadMeses,
      fechaInicio: params.fechaInicio,
    );
  },
);

/// Parámetros para generar items de cuota
class ItemsCuotaParams {
  final bool esResidente;
  final int cantidadMeses;
  final DateTime? fechaInicio;

  ItemsCuotaParams({
    required this.esResidente,
    this.cantidadMeses = 3,
    this.fechaInicio,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemsCuotaParams &&
          runtimeType == other.runtimeType &&
          esResidente == other.esResidente &&
          cantidadMeses == other.cantidadMeses &&
          fechaInicio == other.fechaInicio;

  @override
  int get hashCode =>
      esResidente.hashCode ^ cantidadMeses.hashCode ^ fechaInicio.hashCode;
}
