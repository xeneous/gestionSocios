import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../services/seguimiento_deudas_service.dart';
import '../models/socio_deuda_item.dart';

/// Provider del servicio de seguimiento de deudas
final seguimientoDeudasServiceProvider = Provider<SeguimientoDeudasService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return SeguimientoDeudasService(supabase);
});

/// Parámetros para filtrar búsqueda de deudas
class FiltroSeguimientoParams {
  final int mesesImpagos;
  final bool soloDebitoAutomatico;
  final int? tarjetaId;

  FiltroSeguimientoParams({
    required this.mesesImpagos,
    required this.soloDebitoAutomatico,
    this.tarjetaId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiltroSeguimientoParams &&
          runtimeType == other.runtimeType &&
          mesesImpagos == other.mesesImpagos &&
          soloDebitoAutomatico == other.soloDebitoAutomatico &&
          tarjetaId == other.tarjetaId;

  @override
  int get hashCode =>
      mesesImpagos.hashCode ^
      soloDebitoAutomatico.hashCode ^
      tarjetaId.hashCode;
}

/// Provider para obtener socios con deudas según filtros
final sociosConDeudaProvider =
    FutureProvider.family<List<SocioDeudaItem>, FiltroSeguimientoParams>(
  (ref, params) async {
    final service = ref.watch(seguimientoDeudasServiceProvider);
    return service.buscarSociosConDeuda(
      mesesImpagos: params.mesesImpagos,
      soloDebitoAutomatico: params.soloDebitoAutomatico,
      tarjetaId: params.tarjetaId,
    );
  },
);
