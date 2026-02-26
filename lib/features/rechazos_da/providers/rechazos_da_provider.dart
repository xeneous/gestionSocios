import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rechazo_da_item.dart';
import '../services/rechazos_da_service.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

final rechazosDaServiceProvider = Provider<RechazosDaService>((ref) {
  return RechazosDaService(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum RechazosDaEstado { inicial, buscando, listo, registrando, completado, error }

class RechazosDaState {
  final RechazosDaEstado estado;
  final List<RechazoDAResultado> resultados;
  final String? error;
  final int? registradosCount;
  final String? nombreArchivo;

  const RechazosDaState({
    this.estado = RechazosDaEstado.inicial,
    this.resultados = const [],
    this.error,
    this.registradosCount,
    this.nombreArchivo,
  });

  RechazosDaState copyWith({
    RechazosDaEstado? estado,
    List<RechazoDAResultado>? resultados,
    String? error,
    int? registradosCount,
    String? nombreArchivo,
  }) {
    return RechazosDaState(
      estado: estado ?? this.estado,
      resultados: resultados ?? this.resultados,
      error: error ?? this.error,
      registradosCount: registradosCount ?? this.registradosCount,
      nombreArchivo: nombreArchivo ?? this.nombreArchivo,
    );
  }

  int get totalRechazos => resultados.length;
  int get encontrados => resultados.where((r) => r.daEncontrado).length;
  int get noEncontrados => resultados.where((r) => !r.daEncontrado).length;
  int get seleccionados => resultados.where((r) => r.seleccionado).length;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class RechazosDaNotifier extends Notifier<RechazosDaState> {
  @override
  RechazosDaState build() => const RechazosDaState();

  /// Parsea el contenido del archivo y busca los DA correspondientes en CC.
  Future<void> procesarArchivo(String contenido, String nombreArchivo) async {
    final service = ref.read(rechazosDaServiceProvider);

    state = state.copyWith(
      estado: RechazosDaEstado.buscando,
      nombreArchivo: nombreArchivo,
      error: null,
    );

    try {
      // 1. Parsear archivo
      final rechazos = RechazoDAItem.parsearArchivo(contenido);

      if (rechazos.isEmpty) {
        state = state.copyWith(
          estado: RechazosDaEstado.listo,
          resultados: [],
        );
        return;
      }

      // 2. Buscar DAs en CC
      final resultados = await service.buscarDAs(rechazos);

      state = state.copyWith(
        estado: RechazosDaEstado.listo,
        resultados: resultados,
      );
    } catch (e) {
      state = state.copyWith(
        estado: RechazosDaEstado.error,
        error: e.toString(),
      );
    }
  }

  /// Cambia el estado de selección de un resultado individual.
  void toggleSeleccion(int index) {
    final nuevos = List<RechazoDAResultado>.from(state.resultados);
    nuevos[index] = RechazoDAResultado(
      rechazo: nuevos[index].rechazo,
      idtransaccionDA: nuevos[index].idtransaccionDA,
      socioNombre: nuevos[index].socioNombre,
      seleccionado: !nuevos[index].seleccionado,
    );
    state = state.copyWith(resultados: nuevos);
  }

  /// Selecciona / deselecciona todos los que tienen DA encontrado.
  void toggleTodos(bool seleccionar) {
    final nuevos = state.resultados.map((r) => RechazoDAResultado(
          rechazo: r.rechazo,
          idtransaccionDA: r.idtransaccionDA,
          socioNombre: r.socioNombre,
          seleccionado: r.daEncontrado ? seleccionar : false,
        )).toList();
    state = state.copyWith(resultados: nuevos);
  }

  /// Registra los RDA para los resultados seleccionados.
  Future<void> confirmarRechazos() async {
    final service = ref.read(rechazosDaServiceProvider);

    state = state.copyWith(estado: RechazosDaEstado.registrando, error: null);

    try {
      final aprobados = state.resultados.where((r) => r.seleccionado).toList();
      final count = await service.registrarRechazos(aprobados);
      state = state.copyWith(
        estado: RechazosDaEstado.completado,
        registradosCount: count,
      );
    } catch (e) {
      state = state.copyWith(
        estado: RechazosDaEstado.error,
        error: e.toString(),
      );
    }
  }

  void reiniciar() {
    state = const RechazosDaState();
  }
}

final rechazosDaProvider =
    NotifierProvider<RechazosDaNotifier, RechazosDaState>(
  RechazosDaNotifier.new,
);
