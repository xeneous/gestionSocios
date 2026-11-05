import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Período de trabajo (ej: ejercicio que se está cerrando) compartido por
/// Mayor, Sumas y Saldos, Diagnóstico y Cuentas Corrientes. Se persiste en el
/// navegador para no tener que recargarlo cada vez.
class PeriodoTrabajo {
  final DateTime desde;
  final DateTime hasta;
  const PeriodoTrabajo(this.desde, this.hasta);
}

/// Se sobreescribe en main() con las SharedPreferences ya cargadas.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider no inicializado'),
);

final periodoTrabajoProvider =
    NotifierProvider<PeriodoTrabajoNotifier, PeriodoTrabajo>(
  PeriodoTrabajoNotifier.new,
);

class PeriodoTrabajoNotifier extends Notifier<PeriodoTrabajo> {
  static const _kDesde = 'periodo_trabajo_desde';
  static const _kHasta = 'periodo_trabajo_hasta';

  @override
  PeriodoTrabajo build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final d = DateTime.tryParse(prefs.getString(_kDesde) ?? '');
    final h = DateTime.tryParse(prefs.getString(_kHasta) ?? '');
    if (d != null && h != null) return PeriodoTrabajo(d, h);
    final now = DateTime.now();
    return PeriodoTrabajo(
        DateTime(now.year, 1, 1), DateTime(now.year, now.month + 1, 0));
  }

  void setDesde(DateTime d) => _guardar(PeriodoTrabajo(d, state.hasta));
  void setHasta(DateTime h) => _guardar(PeriodoTrabajo(state.desde, h));

  void _guardar(PeriodoTrabajo p) {
    state = p;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_kDesde, p.desde.toIso8601String());
    prefs.setString(_kHasta, p.hasta.toIso8601String());
  }
}
