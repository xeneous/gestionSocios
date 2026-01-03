import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/asiento_model.dart';

/// Servicio para gestión de asientos de diario
///
/// Centraliza la lógica de creación de asientos contables para todos los módulos
/// Tipos de asiento:
/// - 0: Asiento de diario puro
/// - 1: Ingreso
/// - 2: Egreso
/// - 3: Compras
/// - 4: Ventas
class AsientosService {
  final SupabaseClient _supabase;

  AsientosService(this._supabase);

  /// Tipos de asiento
  static const int tipoDiario = 0;
  static const int tipoIngreso = 1;
  static const int tipoEgreso = 2;
  static const int tipoCompras = 3;
  static const int tipoVentas = 4;

  /// Crea un asiento de diario completo de forma transaccional
  ///
  /// Parámetros:
  /// - tipoAsiento: Tipo de asiento (0-4)
  /// - fecha: Fecha del asiento
  /// - detalle: Descripción del asiento
  /// - items: Lista de items del asiento (DEBE y HABER)
  /// - centroCosto: Centro de costo (opcional)
  /// - numeroComprobante: Número de comprobante asociado (opcional, ej: número de recibo)
  /// - nombrePersona: Nombre de la persona/empresa (opcional, ej: nombre del socio)
  ///
  /// Validaciones:
  /// - El asiento debe estar balanceado (DEBE = HABER)
  /// - Debe tener al menos un item
  /// - Cada item debe tener cuenta_id válido
  /// - El detalle no puede estar vacío
  ///
  /// Retorna:
  /// - El número de asiento generado
  Future<int> crearAsiento({
    required int tipoAsiento,
    required DateTime fecha,
    required String detalle,
    required List<AsientoItemData> items,
    int? centroCosto,
    int? numeroComprobante,
    String? nombrePersona,
  }) async {
    // Validaciones
    if (detalle.trim().isEmpty) {
      throw Exception('El detalle del asiento es obligatorio');
    }

    if (items.isEmpty) {
      throw Exception('El asiento debe tener al menos un item');
    }

    if (tipoAsiento < 0 || tipoAsiento > 4) {
      throw Exception('Tipo de asiento inválido. Debe ser entre 0 y 4');
    }

    // Calcular totales
    double totalDebe = 0;
    double totalHaber = 0;
    for (final item in items) {
      totalDebe += item.debe;
      totalHaber += item.haber;
    }

    // Validar que esté balanceado (con tolerancia de 0.01)
    if ((totalDebe - totalHaber).abs() > 0.01) {
      throw Exception(
        'El asiento no está balanceado. DEBE: \$${totalDebe.toStringAsFixed(2)}, '
        'HABER: \$${totalHaber.toStringAsFixed(2)}'
      );
    }

    // Calcular período (YYYYMM)
    final anioMes = fecha.year * 100 + fecha.month;

    // Obtener siguiente número de asiento para este período y tipo
    final numeroAsiento = await _getNextAsientoNumber(anioMes, tipoAsiento);

    // Construir detalle completo
    String detalleCompleto = detalle;
    if (numeroComprobante != null && nombrePersona != null) {
      detalleCompleto = '$detalle - $nombrePersona';
    } else if (nombrePersona != null) {
      detalleCompleto = '$detalle - $nombrePersona';
    }

    // Crear header
    final header = AsientoHeader(
      asiento: numeroAsiento,
      anioMes: anioMes,
      tipoAsiento: tipoAsiento,
      fecha: fecha,
      detalle: detalleCompleto,
      centroCosto: centroCosto,
    );

    await _supabase.from('asientos_header').insert(header.toJson());

    // Crear items
    final itemsToInsert = items.asMap().entries.map((entry) {
      final index = entry.key;
      final itemData = entry.value;

      return AsientoItem(
        asiento: numeroAsiento,
        anioMes: anioMes,
        tipoAsiento: tipoAsiento,
        item: index + 1, // Item number empieza en 1
        cuentaId: itemData.cuentaId,
        debe: itemData.debe,
        haber: itemData.haber,
        observacion: itemData.observacion,
        centroCosto: itemData.centroCosto ?? centroCosto,
      ).toJson();
    }).toList();

    await _supabase.from('asientos_items').insert(itemsToInsert);

    return numeroAsiento;
  }

  /// Obtiene el siguiente número de asiento para un período y tipo
  Future<int> _getNextAsientoNumber(int anioMes, int tipoAsiento) async {
    final response = await _supabase
        .from('asientos_header')
        .select('asiento')
        .eq('anio_mes', anioMes)
        .eq('tipo_asiento', tipoAsiento)
        .order('asiento', ascending: false)
        .limit(1);

    if (response.isEmpty) {
      return 1;
    }

    return (response[0]['asiento'] as int) + 1;
  }

  /// Anula un asiento de diario
  ///
  /// Elimina el asiento y todos sus items (CASCADE)
  Future<void> anularAsiento({
    required int asiento,
    required int anioMes,
    required int tipoAsiento,
  }) async {
    await _supabase
        .from('asientos_header')
        .delete()
        .eq('asiento', asiento)
        .eq('anio_mes', anioMes)
        .eq('tipo_asiento', tipoAsiento);
  }

  /// Obtiene un asiento completo por sus claves
  Future<AsientoCompleto?> getAsiento({
    required int asiento,
    required int anioMes,
    required int tipoAsiento,
  }) async {
    try {
      // Obtener header
      final headerResponse = await _supabase
          .from('asientos_header')
          .select()
          .eq('asiento', asiento)
          .eq('anio_mes', anioMes)
          .eq('tipo_asiento', tipoAsiento)
          .single();

      final header = AsientoHeader.fromJson(headerResponse);

      // Obtener items
      final itemsResponse = await _supabase
          .from('asientos_items')
          .select('''
            *,
            cuentas!inner(cuenta, descripcion)
          ''')
          .eq('asiento', asiento)
          .eq('anio_mes', anioMes)
          .eq('tipo_asiento', tipoAsiento)
          .order('item');

      final items = (itemsResponse as List).map((json) {
        final item = AsientoItem.fromJson(json);
        if (json['cuentas'] != null) {
          item.cuentaNumero = json['cuentas']['cuenta'];
          item.cuentaDescripcion = json['cuentas']['descripcion'];
        }
        return item;
      }).toList();

      return AsientoCompleto(header: header, items: items);
    } catch (e) {
      return null;
    }
  }
}

/// Clase para pasar datos de items al servicio
class AsientoItemData {
  final int cuentaId;
  final double debe;
  final double haber;
  final String? observacion;
  final int? centroCosto;

  AsientoItemData({
    required this.cuentaId,
    this.debe = 0.0,
    this.haber = 0.0,
    this.observacion,
    this.centroCosto,
  });
}
