import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../services/debitos_automaticos_service.dart';
import '../models/tarjeta_model.dart';
import '../models/debito_automatico_item.dart';

/// Provider del servicio de débitos automáticos
final debitosAutomaticosServiceProvider = Provider<DebitosAutomaticosService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return DebitosAutomaticosService(supabase);
});

/// Provider para obtener tarjetas activas
final tarjetasActivasProvider = FutureProvider<List<Tarjeta>>((ref) async {
  final service = ref.watch(debitosAutomaticosServiceProvider);
  return service.getTarjetasActivas();
});

/// Parámetros para filtrar movimientos pendientes
class FiltroDebitosParams {
  final int anioMes;
  final int? tarjetaId;

  FiltroDebitosParams({
    required this.anioMes,
    this.tarjetaId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiltroDebitosParams &&
          runtimeType == other.runtimeType &&
          anioMes == other.anioMes &&
          tarjetaId == other.tarjetaId;

  @override
  int get hashCode => anioMes.hashCode ^ tarjetaId.hashCode;
}

/// Provider para obtener movimientos pendientes según filtros
final movimientosPendientesProvider =
    FutureProvider.family<List<DebitoAutomaticoItem>, FiltroDebitosParams>(
  (ref, params) async {
    final service = ref.watch(debitosAutomaticosServiceProvider);
    return service.getMovimientosPendientes(
      anioMes: params.anioMes,
      tarjetaId: params.tarjetaId,
    );
  },
);

/// Provider para obtener estadísticas de débitos
final estadisticasDebitosProvider =
    FutureProvider.family<Map<String, dynamic>, FiltroDebitosParams>(
  (ref, params) async {
    final service = ref.watch(debitosAutomaticosServiceProvider);
    return service.getEstadisticas(
      anioMes: params.anioMes,
      tarjetaId: params.tarjetaId,
    );
  },
);
