import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../models/rechazo_historico.dart';
import '../services/historial_rechazos_service.dart';

final historialRechazosServiceProvider =
    Provider<HistorialRechazosService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return HistorialRechazosService(supabase);
});

class HistorialParams {
  final int? tarjetaId;
  final int? periodo;

  const HistorialParams({this.tarjetaId, this.periodo});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistorialParams &&
          runtimeType == other.runtimeType &&
          tarjetaId == other.tarjetaId &&
          periodo == other.periodo;

  @override
  int get hashCode => tarjetaId.hashCode ^ periodo.hashCode;
}

final historialRechazosProvider =
    FutureProvider.family<List<RechazoHistorico>, HistorialParams>(
  (ref, params) async {
    final service = ref.watch(historialRechazosServiceProvider);
    return service.getRechazos(
      tarjetaId: params.tarjetaId,
      periodo: params.periodo,
    );
  },
);
