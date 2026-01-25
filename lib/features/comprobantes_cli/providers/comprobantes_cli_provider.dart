import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comprobante_cli_model.dart';
import '../services/comprobantes_cli_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Provider del servicio
final comprobantesCliServiceProvider = Provider<ComprobantesCliService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return ComprobantesCliService(supabase);
});

// Parámetros de búsqueda
class VenCliSearchParams {
  final int? cliente;
  final int? tipoComprobante;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final String? nroComprobante;
  final bool soloConSaldo;

  VenCliSearchParams({
    this.cliente,
    this.tipoComprobante,
    this.fechaDesde,
    this.fechaHasta,
    this.nroComprobante,
    this.soloConSaldo = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VenCliSearchParams &&
          runtimeType == other.runtimeType &&
          cliente == other.cliente &&
          tipoComprobante == other.tipoComprobante &&
          fechaDesde == other.fechaDesde &&
          fechaHasta == other.fechaHasta &&
          nroComprobante == other.nroComprobante &&
          soloConSaldo == other.soloConSaldo;

  @override
  int get hashCode =>
      cliente.hashCode ^
      tipoComprobante.hashCode ^
      fechaDesde.hashCode ^
      fechaHasta.hashCode ^
      nroComprobante.hashCode ^
      soloConSaldo.hashCode;
}

// Provider para búsqueda de comprobantes
final comprobantesCliSearchProvider =
    FutureProvider.family<List<VenCliHeader>, VenCliSearchParams>(
        (ref, params) async {
  final service = ref.watch(comprobantesCliServiceProvider);
  return service.buscarComprobantes(
    cliente: params.cliente,
    tipoComprobante: params.tipoComprobante,
    fechaDesde: params.fechaDesde,
    fechaHasta: params.fechaHasta,
    nroComprobante: params.nroComprobante,
    soloConSaldo: params.soloConSaldo,
  );
});

// Provider para obtener un comprobante por ID
final comprobanteCliProvider =
    FutureProvider.family<VenCliHeader?, int>((ref, idTransaccion) async {
  final service = ref.watch(comprobantesCliServiceProvider);
  return service.getComprobante(idTransaccion);
});

// Provider para comprobantes de un cliente específico
final comprobantesDeClienteProvider =
    FutureProvider.family<List<VenCliHeader>, int>((ref, clienteId) async {
  final service = ref.watch(comprobantesCliServiceProvider);
  return service.getComprobantesPorCliente(clienteId);
});

// Provider para tipos de comprobante de ventas
final tiposComprobanteVentaProvider =
    FutureProvider<List<TipoComprobanteVenta>>((ref) async {
  final service = ref.watch(comprobantesCliServiceProvider);
  return service.getTiposComprobante();
});

// Notifier para operaciones CRUD
class ComprobantesCliNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<VenCliHeader> crearComprobante(
    VenCliHeader header,
    List<VenCliItem> items,
  ) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(comprobantesCliServiceProvider);
      final nuevoComprobante = await service.crearComprobante(header, items);
      state = const AsyncValue.data(null);
      return nuevoComprobante;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<VenCliHeader> actualizarComprobante(
    VenCliHeader header,
    List<VenCliItem> items,
  ) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(comprobantesCliServiceProvider);
      final comprobanteActualizado =
          await service.actualizarComprobante(header, items);
      state = const AsyncValue.data(null);
      return comprobanteActualizado;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> eliminarComprobante(int idTransaccion) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(comprobantesCliServiceProvider);
      await service.eliminarComprobante(idTransaccion);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> registrarCancelacion(int idTransaccion, double monto) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(comprobantesCliServiceProvider);
      await service.registrarCancelacion(idTransaccion, monto);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final comprobantesCliNotifierProvider =
    NotifierProvider<ComprobantesCliNotifier, AsyncValue<void>>(
        ComprobantesCliNotifier.new);

// Estado de búsqueda persistente
class VenCliSearchState {
  final String clienteCodigo;
  final String nroComprobante;
  final int? tipoComprobante;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final bool soloConSaldo;
  final bool hasSearched;
  final List<VenCliHeader> resultados;

  VenCliSearchState({
    this.clienteCodigo = '',
    this.nroComprobante = '',
    this.tipoComprobante,
    this.fechaDesde,
    this.fechaHasta,
    this.soloConSaldo = false,
    this.hasSearched = false,
    this.resultados = const [],
  });

  VenCliSearchState copyWith({
    String? clienteCodigo,
    String? nroComprobante,
    int? tipoComprobante,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    bool? soloConSaldo,
    bool? hasSearched,
    List<VenCliHeader>? resultados,
    bool clearTipoComprobante = false,
    bool clearFechaDesde = false,
    bool clearFechaHasta = false,
  }) {
    return VenCliSearchState(
      clienteCodigo: clienteCodigo ?? this.clienteCodigo,
      nroComprobante: nroComprobante ?? this.nroComprobante,
      tipoComprobante:
          clearTipoComprobante ? null : (tipoComprobante ?? this.tipoComprobante),
      fechaDesde: clearFechaDesde ? null : (fechaDesde ?? this.fechaDesde),
      fechaHasta: clearFechaHasta ? null : (fechaHasta ?? this.fechaHasta),
      soloConSaldo: soloConSaldo ?? this.soloConSaldo,
      hasSearched: hasSearched ?? this.hasSearched,
      resultados: resultados ?? this.resultados,
    );
  }

  VenCliSearchParams toSearchParams() {
    return VenCliSearchParams(
      cliente: clienteCodigo.isNotEmpty ? int.tryParse(clienteCodigo) : null,
      tipoComprobante: tipoComprobante,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
      nroComprobante: nroComprobante.isNotEmpty ? nroComprobante : null,
      soloConSaldo: soloConSaldo,
    );
  }

  bool get hasFilters =>
      clienteCodigo.isNotEmpty ||
      nroComprobante.isNotEmpty ||
      tipoComprobante != null ||
      fechaDesde != null ||
      fechaHasta != null ||
      soloConSaldo;
}

class VenCliSearchStateNotifier extends Notifier<VenCliSearchState> {
  @override
  VenCliSearchState build() {
    return VenCliSearchState();
  }

  void updateClienteCodigo(String value) {
    state = state.copyWith(clienteCodigo: value);
  }

  void updateNroComprobante(String value) {
    state = state.copyWith(nroComprobante: value);
  }

  void updateTipoComprobante(int? value) {
    if (value == null) {
      state = state.copyWith(clearTipoComprobante: true);
    } else {
      state = state.copyWith(tipoComprobante: value);
    }
  }

  void updateFechaDesde(DateTime? value) {
    if (value == null) {
      state = state.copyWith(clearFechaDesde: true);
    } else {
      state = state.copyWith(fechaDesde: value);
    }
  }

  void updateFechaHasta(DateTime? value) {
    if (value == null) {
      state = state.copyWith(clearFechaHasta: true);
    } else {
      state = state.copyWith(fechaHasta: value);
    }
  }

  void updateSoloConSaldo(bool value) {
    state = state.copyWith(soloConSaldo: value);
  }

  void setResultados(List<VenCliHeader> comprobantes) {
    state = state.copyWith(resultados: comprobantes, hasSearched: true);
  }

  void clearSearch() {
    state = VenCliSearchState();
  }

  void clearResults() {
    state = state.copyWith(resultados: [], hasSearched: false);
  }
}

final venCliSearchStateProvider =
    NotifierProvider<VenCliSearchStateNotifier, VenCliSearchState>(
        VenCliSearchStateNotifier.new);
