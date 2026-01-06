import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/socio_deuda_item.dart';

/// Clase auxiliar temporal para agrupar deudas por socio
class _SocioDeudaTemp {
  final int socioId;
  final String apellido;
  final String nombre;
  final String? email;
  final bool adheridoDebito;
  final int? tarjetaId;
  final List<DeudaDetalle> deudas = [];

  _SocioDeudaTemp({
    required this.socioId,
    required this.apellido,
    required this.nombre,
    this.email,
    required this.adheridoDebito,
    this.tarjetaId,
  });
}

class SeguimientoDeudasService {
  final SupabaseClient _supabase;

  SeguimientoDeudasService(this._supabase);

  /// Obtiene los socios con deudas según los filtros
  ///
  /// Parámetros:
  /// - [mesesImpagos]: Cantidad mínima de meses impagos
  /// - [soloDebitoAutomatico]: Si es true, solo socios con débito automático
  /// - [tarjetaId]: Filtrar por tarjeta específica (solo si soloDebitoAutomatico = true)
  Future<List<SocioDeudaItem>> buscarSociosConDeuda({
    required int mesesImpagos,
    required bool soloDebitoAutomatico,
    int? tarjetaId,
  }) async {
    // Query eficiente: obtener cuentas corrientes con saldo pendiente y datos del socio
    var query = _supabase
        .from('cuentas_corrientes')
        .select('''
          socio_id,
          documento_numero,
          importe,
          cancelado,
          vencimiento,
          socios!inner(
            id,
            apellido,
            nombre,
            email,
            adherido_debito,
            tarjeta_id
          )
        ''');

    // Filtrar por débito automático si es necesario
    if (soloDebitoAutomatico) {
      query = query.eq('socios.adherido_debito', true);

      if (tarjetaId != null) {
        query = query.eq('socios.tarjeta_id', tarjetaId);
      }
    }

    final response = await query.order('socio_id').order('documento_numero');
    final movimientos = response as List;

    // Agrupar por socio y calcular deudas
    final sociosDeudasMap = <int, _SocioDeudaTemp>{};

    for (final mov in movimientos) {
      final socioData = mov['socios'];
      final socioId = socioData['id'] as int;
      final importe = (mov['importe'] as num?)?.toDouble() ?? 0.0;
      final cancelado = (mov['cancelado'] as num?)?.toDouble() ?? 0.0;
      final saldo = importe - cancelado;

      // Solo procesar si tiene saldo pendiente
      if (saldo > 0) {
        // Crear o actualizar el registro del socio
        if (!sociosDeudasMap.containsKey(socioId)) {
          sociosDeudasMap[socioId] = _SocioDeudaTemp(
            socioId: socioId,
            apellido: socioData['apellido'] as String,
            nombre: socioData['nombre'] as String,
            email: socioData['email'] as String?,
            adheridoDebito: socioData['adherido_debito'] as bool? ?? false,
            tarjetaId: socioData['tarjeta_id'] as int?,
          );
        }

        // Agregar el detalle de la deuda
        sociosDeudasMap[socioId]!.deudas.add(DeudaDetalle(
          documentoNumero: mov['documento_numero'] as String,
          importe: saldo,
          vencimiento: mov['vencimiento'] != null
              ? DateTime.parse(mov['vencimiento'] as String)
              : null,
        ));
      }
    }

    // Filtrar por cantidad mínima de meses impagos y convertir a lista
    final sociosConDeuda = <SocioDeudaItem>[];

    for (final temp in sociosDeudasMap.values) {
      if (temp.deudas.length >= mesesImpagos) {
        final importeTotal = temp.deudas.fold<double>(
          0,
          (sum, deuda) => sum + deuda.importe,
        );

        sociosConDeuda.add(SocioDeudaItem(
          socioId: temp.socioId,
          apellido: temp.apellido,
          nombre: temp.nombre,
          mesesMora: temp.deudas.length,
          importeTotal: importeTotal,
          email: temp.email,
          adheridoDebito: temp.adheridoDebito,
          tarjetaId: temp.tarjetaId,
          detalles: temp.deudas,
        ));
      }
    }

    // Ordenar por cantidad de meses mora (descendente)
    sociosConDeuda.sort((a, b) => b.mesesMora.compareTo(a.mesesMora));

    return sociosConDeuda;
  }

  /// Envía notificación de deuda a un socio
  /// TODO: Implementar envío de email
  Future<void> enviarNotificacion({
    required int socioId,
    required String email,
    required List<DeudaDetalle> deudas,
  }) async {
    // TODO: Implementar lógica de envío de email
    // Por ahora solo simular
    await Future.delayed(const Duration(milliseconds: 500));

    // Aquí se podría:
    // 1. Llamar a una Cloud Function de Firebase
    // 2. Usar un servicio de email (SendGrid, etc.)
    // 3. Registrar la notificación en una tabla de log

    print('Notificación enviada a $email para socio $socioId');
  }
}
