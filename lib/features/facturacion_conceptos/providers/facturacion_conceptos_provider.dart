import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../services/facturacion_conceptos_service.dart';

/// Provider del servicio de facturación de conceptos
final facturacionConceptosServiceProvider = Provider<FacturacionConceptosService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return FacturacionConceptosService(supabase);
});

/// Provider para obtener facturas de un socio
final facturasSocioProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, socioId) async {
  final service = ref.watch(facturacionConceptosServiceProvider);
  return service.getFacturasSocio(socioId);
});

/// Provider para obtener detalle de una factura
final detalleFacturaProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, idtransaccion) async {
  final service = ref.watch(facturacionConceptosServiceProvider);
  return service.getDetalleFactura(idtransaccion);
});
