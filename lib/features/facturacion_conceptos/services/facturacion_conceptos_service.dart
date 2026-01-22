import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/factura_concepto_model.dart';

class FacturacionConceptosService {
  final SupabaseClient _supabase;

  FacturacionConceptosService(this._supabase);

  /// Crea una factura de conceptos (FC) para un socio
  /// Retorna el idtransaccion de la factura creada
  Future<FacturaConceptoCreada> crearFactura(NuevaFacturaConcepto factura) async {
    if (factura.items.isEmpty) {
      throw Exception('La factura debe tener al menos un concepto');
    }

    // Obtener el siguiente número de documento para hoy
    final documentoNumero = await _generarNumeroDocumento(factura.fecha);

    // Calcular vencimiento (si no se especifica, 30 días desde la fecha)
    final vencimiento = factura.vencimiento ??
        factura.fecha.add(const Duration(days: 30));

    // Crear header de la transacción
    final transaccion = {
      'socio_id': factura.socioId,
      'entidad_id': 0, // 0 = Socios
      'fecha': factura.fecha.toIso8601String(),
      'tipo_comprobante': 'FC',
      'documento_numero': documentoNumero,
      'importe': factura.total,
      'cancelado': 0,
      'vencimiento': vencimiento.toIso8601String(),
    };

    final response = await _supabase
        .from('cuentas_corrientes')
        .insert(transaccion)
        .select('idtransaccion')
        .single();

    final idtransaccion = response['idtransaccion'] as int;

    // Crear detalles de la transacción
    final detalles = <Map<String, dynamic>>[];
    for (int i = 0; i < factura.items.length; i++) {
      detalles.add(factura.items[i].toDetalleJson(idtransaccion, i + 1));
    }

    await _supabase.from('detalle_cuentas_corrientes').insert(detalles);

    return FacturaConceptoCreada(
      idtransaccion: idtransaccion,
      documentoNumero: documentoNumero,
      importe: factura.total,
    );
  }

  /// Genera un número de documento único para la fecha
  Future<String> _generarNumeroDocumento(DateTime fecha) async {
    final fechaStr =
        '${fecha.year}${fecha.month.toString().padLeft(2, '0')}${fecha.day.toString().padLeft(2, '0')}';

    // Buscar el último documento del día
    final response = await _supabase
        .from('cuentas_corrientes')
        .select('documento_numero')
        .eq('tipo_comprobante', 'FC')
        .like('documento_numero', '$fechaStr-%')
        .order('documento_numero', ascending: false)
        .limit(1)
        .maybeSingle();

    int secuencial = 1;
    if (response != null) {
      final ultimoNumero = response['documento_numero'] as String;
      final partes = ultimoNumero.split('-');
      if (partes.length == 2) {
        secuencial = (int.tryParse(partes[1]) ?? 0) + 1;
      }
    }

    return '$fechaStr-${secuencial.toString().padLeft(4, '0')}';
  }

  /// Obtiene las facturas de conceptos de un socio
  Future<List<Map<String, dynamic>>> getFacturasSocio(int socioId) async {
    final response = await _supabase
        .from('cuentas_corrientes')
        .select()
        .eq('socio_id', socioId)
        .eq('tipo_comprobante', 'FC')
        .order('fecha', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene el detalle de una factura
  Future<List<Map<String, dynamic>>> getDetalleFactura(int idtransaccion) async {
    final response = await _supabase
        .from('detalle_cuentas_corrientes')
        .select('*, conceptos(descripcion)')
        .eq('idtransaccion', idtransaccion)
        .order('item');

    return List<Map<String, dynamic>>.from(response);
  }
}
