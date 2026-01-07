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
  final bool mesesOMas; // true = meses >= N, false = meses == N

  FiltroSeguimientoParams({
    required this.mesesImpagos,
    required this.soloDebitoAutomatico,
    this.tarjetaId,
    this.mesesOMas = true, // Por defecto "o más"
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiltroSeguimientoParams &&
          runtimeType == other.runtimeType &&
          mesesImpagos == other.mesesImpagos &&
          soloDebitoAutomatico == other.soloDebitoAutomatico &&
          tarjetaId == other.tarjetaId &&
          mesesOMas == other.mesesOMas;

  @override
  int get hashCode =>
      mesesImpagos.hashCode ^
      soloDebitoAutomatico.hashCode ^
      tarjetaId.hashCode ^
      mesesOMas.hashCode;
}

/// Tamaño de página para seguimiento de deudas
const int seguimientoDeudasPageSize = 50;

/// Parámetros extendidos con paginación
class FiltroSeguimientoParamsConPaginacion {
  final FiltroSeguimientoParams filtro;
  final int pagina;

  FiltroSeguimientoParamsConPaginacion({
    required this.filtro,
    this.pagina = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiltroSeguimientoParamsConPaginacion &&
          runtimeType == other.runtimeType &&
          filtro == other.filtro &&
          pagina == other.pagina;

  @override
  int get hashCode => filtro.hashCode ^ pagina.hashCode;
}

/// Provider para obtener socios con deudas según filtros (paginado)
final sociosConDeudaProvider =
    FutureProvider.family<Map<String, dynamic>, FiltroSeguimientoParamsConPaginacion>(
  (ref, params) async {
    final service = ref.watch(seguimientoDeudasServiceProvider);

    return service.buscarSociosConDeuda(
      mesesImpagos: params.filtro.mesesImpagos,
      soloDebitoAutomatico: params.filtro.soloDebitoAutomatico,
      tarjetaId: params.filtro.tarjetaId,
      mesesOMas: params.filtro.mesesOMas,
      limit: seguimientoDeudasPageSize,
      offset: params.pagina * seguimientoDeudasPageSize,
    );
  },
);
