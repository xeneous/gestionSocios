import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comprobante_prov_model.dart';
import '../services/comprobantes_prov_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Provider del servicio
final comprobantesProvServiceProvider = Provider<ComprobantesProvService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return ComprobantesProvService(supabase);
});

// Parámetros de búsqueda
class CompProvSearchParams {
  final int? proveedor;
  final int? tipoComprobante;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final String? nroComprobante;
  final bool soloConSaldo;

  CompProvSearchParams({
    this.proveedor,
    this.tipoComprobante,
    this.fechaDesde,
    this.fechaHasta,
    this.nroComprobante,
    this.soloConSaldo = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompProvSearchParams &&
          runtimeType == other.runtimeType &&
          proveedor == other.proveedor &&
          tipoComprobante == other.tipoComprobante &&
          fechaDesde == other.fechaDesde &&
          fechaHasta == other.fechaHasta &&
          nroComprobante == other.nroComprobante &&
          soloConSaldo == other.soloConSaldo;

  @override
  int get hashCode =>
      proveedor.hashCode ^
      tipoComprobante.hashCode ^
      fechaDesde.hashCode ^
      fechaHasta.hashCode ^
      nroComprobante.hashCode ^
      soloConSaldo.hashCode;
}

// Provider para búsqueda de comprobantes
final comprobantesProvSearchProvider =
    FutureProvider.family<List<CompProvHeader>, CompProvSearchParams>(
        (ref, params) async {
  final service = ref.watch(comprobantesProvServiceProvider);
  return service.buscarComprobantes(
    proveedor: params.proveedor,
    tipoComprobante: params.tipoComprobante,
    fechaDesde: params.fechaDesde,
    fechaHasta: params.fechaHasta,
    nroComprobante: params.nroComprobante,
    soloConSaldo: params.soloConSaldo,
  );
});

// Provider para obtener un comprobante por ID
final comprobanteProvProvider =
    FutureProvider.family<CompProvHeader?, int>((ref, idTransaccion) async {
  final service = ref.watch(comprobantesProvServiceProvider);
  return service.getComprobante(idTransaccion);
});

// Provider para comprobantes de un proveedor específico
final comprobantesDeProveedorProvider =
    FutureProvider.family<List<CompProvHeader>, int>((ref, proveedorId) async {
  final service = ref.watch(comprobantesProvServiceProvider);
  return service.getComprobantesPorProveedor(proveedorId);
});

// Provider para tipos de comprobante de compras
final tiposComprobanteCompraProvider =
    FutureProvider<List<TipoComprobanteCompra>>((ref) async {
  final service = ref.watch(comprobantesProvServiceProvider);
  return service.getTiposComprobante();
});

// Notifier para operaciones CRUD
class ComprobantesProvNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<CompProvHeader> crearComprobante(
    CompProvHeader header,
    List<CompProvItem> items,
  ) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(comprobantesProvServiceProvider);
      final nuevoComprobante = await service.crearComprobante(header, items);
      state = const AsyncValue.data(null);
      return nuevoComprobante;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<CompProvHeader> actualizarComprobante(
    CompProvHeader header,
    List<CompProvItem> items,
  ) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(comprobantesProvServiceProvider);
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
      final service = ref.read(comprobantesProvServiceProvider);
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
      final service = ref.read(comprobantesProvServiceProvider);
      await service.registrarCancelacion(idTransaccion, monto);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final comprobantesProvNotifierProvider =
    NotifierProvider<ComprobantesProvNotifier, AsyncValue<void>>(
        ComprobantesProvNotifier.new);

// Estado de búsqueda persistente
class CompProvSearchState {
  final String proveedorCodigo;
  final String nroComprobante;
  final int? tipoComprobante;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final bool soloConSaldo;
  final bool hasSearched;
  final List<CompProvHeader> resultados;

  CompProvSearchState({
    this.proveedorCodigo = '',
    this.nroComprobante = '',
    this.tipoComprobante,
    this.fechaDesde,
    this.fechaHasta,
    this.soloConSaldo = false,
    this.hasSearched = false,
    this.resultados = const [],
  });

  CompProvSearchState copyWith({
    String? proveedorCodigo,
    String? nroComprobante,
    int? tipoComprobante,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    bool? soloConSaldo,
    bool? hasSearched,
    List<CompProvHeader>? resultados,
    bool clearTipoComprobante = false,
    bool clearFechaDesde = false,
    bool clearFechaHasta = false,
  }) {
    return CompProvSearchState(
      proveedorCodigo: proveedorCodigo ?? this.proveedorCodigo,
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

  CompProvSearchParams toSearchParams() {
    return CompProvSearchParams(
      proveedor:
          proveedorCodigo.isNotEmpty ? int.tryParse(proveedorCodigo) : null,
      tipoComprobante: tipoComprobante,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
      nroComprobante: nroComprobante.isNotEmpty ? nroComprobante : null,
      soloConSaldo: soloConSaldo,
    );
  }

  bool get hasFilters =>
      proveedorCodigo.isNotEmpty ||
      nroComprobante.isNotEmpty ||
      tipoComprobante != null ||
      fechaDesde != null ||
      fechaHasta != null ||
      soloConSaldo;
}

class CompProvSearchStateNotifier extends Notifier<CompProvSearchState> {
  @override
  CompProvSearchState build() {
    return CompProvSearchState();
  }

  void updateProveedorCodigo(String value) {
    state = state.copyWith(proveedorCodigo: value);
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

  void setResultados(List<CompProvHeader> comprobantes) {
    state = state.copyWith(resultados: comprobantes, hasSearched: true);
  }

  void clearSearch() {
    state = CompProvSearchState();
  }

  void clearResults() {
    state = state.copyWith(resultados: [], hasSearched: false);
  }
}

final compProvSearchStateProvider =
    NotifierProvider<CompProvSearchStateNotifier, CompProvSearchState>(
        CompProvSearchStateNotifier.new);
