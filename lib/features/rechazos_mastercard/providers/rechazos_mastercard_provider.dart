import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rechazo_mastercard_item.dart';
import '../services/rechazos_mastercard_service.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

final rechazosMastercardServiceProvider =
    Provider<RechazosMastercardService>((ref) {
  return RechazosMastercardService(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum RechazosMastercardEstado {
  inicial,
  buscando,
  listo,
  registrando,
  completado,
  error,
}

class RechazosMastercardState {
  final RechazosMastercardEstado estado;
  final DateTime? fechaPresentacion;
  final List<RechazoMastercardResultado> resultados;
  final String? error;
  final int? rechazosRegistrados;
  final int? tarjetasActualizadas;
  final String? nombreArchivo;

  const RechazosMastercardState({
    this.estado = RechazosMastercardEstado.inicial,
    this.fechaPresentacion,
    this.resultados = const [],
    this.error,
    this.rechazosRegistrados,
    this.tarjetasActualizadas,
    this.nombreArchivo,
  });

  RechazosMastercardState copyWith({
    RechazosMastercardEstado? estado,
    DateTime? fechaPresentacion,
    List<RechazoMastercardResultado>? resultados,
    String? error,
    int? rechazosRegistrados,
    int? tarjetasActualizadas,
    String? nombreArchivo,
  }) {
    return RechazosMastercardState(
      estado: estado ?? this.estado,
      fechaPresentacion: fechaPresentacion ?? this.fechaPresentacion,
      resultados: resultados ?? this.resultados,
      error: error ?? this.error,
      rechazosRegistrados: rechazosRegistrados ?? this.rechazosRegistrados,
      tarjetasActualizadas: tarjetasActualizadas ?? this.tarjetasActualizadas,
      nombreArchivo: nombreArchivo ?? this.nombreArchivo,
    );
  }

  List<RechazoMastercardResultado> get soloRechazos =>
      resultados.where((r) => r.item.esRechazo).toList();

  List<RechazoMastercardResultado> get soloObservados =>
      resultados.where((r) => r.item.esObservado).toList();

  int get totalRechazos => soloRechazos.length;
  int get rechazosEncontrados =>
      soloRechazos.where((r) => r.daEncontrado).length;
  int get rechazosNoEncontrados =>
      soloRechazos.where((r) => !r.daEncontrado).length;
  int get rechazosSeleccionados =>
      soloRechazos.where((r) => r.seleccionado).length;

  int get totalObservados => soloObservados.length;
  int get observadosSeleccionados =>
      soloObservados.where((r) => r.seleccionado).length;

  int get totalSeleccionados => rechazosSeleccionados + observadosSeleccionados;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class RechazosMastercardNotifier extends Notifier<RechazosMastercardState> {
  @override
  RechazosMastercardState build() => const RechazosMastercardState();

  /// Parsea el archivo y busca los DA correspondientes en CC.
  Future<void> procesarArchivo(
      String contenido, String nombreArchivo, DateTime fechaPresentacion) async {
    final service = ref.read(rechazosMastercardServiceProvider);

    state = state.copyWith(
      estado: RechazosMastercardEstado.buscando,
      fechaPresentacion: fechaPresentacion,
      nombreArchivo: nombreArchivo,
      error: null,
    );

    try {
      final items =
          RechazoMastercardItem.parsearArchivo(contenido, fechaPresentacion);

      if (items.isEmpty) {
        state = state.copyWith(
          estado: RechazosMastercardEstado.listo,
          resultados: [],
        );
        return;
      }

      final resultados = await service.buscarDAs(items);

      state = state.copyWith(
        estado: RechazosMastercardEstado.listo,
        resultados: resultados,
      );
    } catch (e) {
      state = state.copyWith(
        estado: RechazosMastercardEstado.error,
        error: e.toString(),
      );
    }
  }

  void toggleSeleccion(int indexEnResultados) {
    final nuevos = List<RechazoMastercardResultado>.from(state.resultados);
    final r = nuevos[indexEnResultados];
    nuevos[indexEnResultados] = RechazoMastercardResultado(
      item: r.item,
      idtransaccionDA: r.idtransaccionDA,
      socioNombre: r.socioNombre,
      seleccionado: !r.seleccionado,
    );
    state = state.copyWith(resultados: nuevos);
  }

  void toggleTodosRechazos(bool seleccionar) {
    final nuevos = state.resultados.map((r) {
      if (!r.item.esRechazo) return r;
      return RechazoMastercardResultado(
        item: r.item,
        idtransaccionDA: r.idtransaccionDA,
        socioNombre: r.socioNombre,
        seleccionado: r.daEncontrado ? seleccionar : false,
      );
    }).toList();
    state = state.copyWith(resultados: nuevos);
  }

  void toggleTodosObservados(bool seleccionar) {
    final nuevos = state.resultados.map((r) {
      if (!r.item.esObservado) return r;
      return RechazoMastercardResultado(
        item: r.item,
        idtransaccionDA: r.idtransaccionDA,
        socioNombre: r.socioNombre,
        seleccionado: seleccionar,
      );
    }).toList();
    state = state.copyWith(resultados: nuevos);
  }

  /// Confirma: actualiza tarjetas (observados) + registra RDA (rechazos).
  Future<void> confirmar() async {
    final service = ref.read(rechazosMastercardServiceProvider);

    state = state.copyWith(
        estado: RechazosMastercardEstado.registrando, error: null);

    try {
      final tarjetasActualizadas =
          await service.actualizarTarjetas(state.resultados);
      final rechazosRegistrados =
          await service.registrarRechazos(state.resultados);

      state = state.copyWith(
        estado: RechazosMastercardEstado.completado,
        rechazosRegistrados: rechazosRegistrados,
        tarjetasActualizadas: tarjetasActualizadas,
      );
    } catch (e) {
      state = state.copyWith(
        estado: RechazosMastercardEstado.error,
        error: e.toString(),
      );
    }
  }

  void reiniciar() => state = const RechazosMastercardState();
}

final rechazosMastercardProvider = NotifierProvider<RechazosMastercardNotifier,
    RechazosMastercardState>(
  RechazosMastercardNotifier.new,
);
