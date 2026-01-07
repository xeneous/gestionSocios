import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cuenta_corriente_resumen.dart';

class CuentasCorrientesService {
  final SupabaseClient _supabase;

  CuentasCorrientesService(this._supabase);

  /// Obtiene el resumen de cuentas corrientes de todos los socios activos
  ///
  /// Optimizado con función RPC para procesar en el servidor
  ///
  /// [limit] - Cantidad de registros a obtener (null = todos)
  /// [offset] - Número de registros a saltar
  Future<Map<String, dynamic>> obtenerResumenCuentasCorrientes({
    int? limit,
    int offset = 0,
  }) async {
    try {
      // Llamar a función RPC optimizada con paginación
      final response = await _supabase.rpc(
        'obtener_resumen_cuentas_corrientes',
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final rows = response as List;

      int totalCount = 0;
      final items = rows.map((row) {
        // El total_count viene en cada fila, tomamos el de la primera
        if (totalCount == 0 && row['total_count'] != null) {
          totalCount = (row['total_count'] as num).toInt();
        }

        return CuentaCorrienteResumen(
          socioId: row['socio_id'] as int,
          apellido: row['apellido'] as String,
          nombre: row['nombre'] as String,
          grupo: row['grupo'] as String?,
          saldo: (row['saldo'] as num).toDouble(),
          rdaPendiente: (row['rda_pendiente'] as num).toDouble(),
          telefono: row['telefono'] as String?,
          email: row['email'] as String?,
        );
      }).toList();

      return {
        'items': items,
        'totalCount': totalCount,
      };
    } catch (e) {
      // Fallback: método legacy
      print('Error al llamar RPC: $e');
      final items = await _obtenerResumenLegacy();
      return {
        'items': items,
        'totalCount': items.length,
      };
    }
  }

  /// Obtiene TODO el resumen sin paginación (para exportar a Excel)
  Future<List<CuentaCorrienteResumen>> obtenerResumenCompletoParaExportar() async {
    final result = await obtenerResumenCuentasCorrientes(limit: null, offset: 0);
    return result['items'] as List<CuentaCorrienteResumen>;
  }

  /// Método legacy - procesa en el cliente
  Future<List<CuentaCorrienteResumen>> _obtenerResumenLegacy() async {
    // Obtener todos los socios activos
    final sociosResponse = await _supabase
        .from('socios')
        .select('id, apellido, nombre, grupo, telefono, email')
        .eq('activo', true)
        .order('apellido')
        .order('nombre');

    final socios = sociosResponse as List;
    final resumenList = <CuentaCorrienteResumen>[];

    for (final socio in socios) {
      final socioId = socio['id'] as int;

      // Obtener saldo total (importe - cancelado)
      final cuentasResponse = await _supabase
          .from('cuentas_corrientes')
          .select('importe, cancelado, tipo_comprobante')
          .eq('socio_id', socioId);

      final cuentas = cuentasResponse as List;
      double saldoTotal = 0;
      double rdaPendiente = 0;

      for (final cuenta in cuentas) {
        final importe = (cuenta['importe'] as num?)?.toDouble() ?? 0.0;
        final cancelado = (cuenta['cancelado'] as num?)?.toDouble() ?? 0.0;
        final saldo = importe - cancelado;

        saldoTotal += saldo;

        // Sumar RDA pendientes (tipo_comprobante = 'RDA')
        if (cuenta['tipo_comprobante'] == 'RDA' && saldo > 0) {
          rdaPendiente += saldo;
        }
      }

      resumenList.add(CuentaCorrienteResumen(
        socioId: socioId,
        apellido: socio['apellido'] as String,
        nombre: socio['nombre'] as String,
        grupo: socio['grupo'] as String?,
        saldo: saldoTotal,
        rdaPendiente: rdaPendiente,
        telefono: socio['telefono'] as String?,
        email: socio['email'] as String?,
      ));
    }

    return resumenList;
  }

  /// Envía email al socio con el resumen de su cuenta corriente
  /// TODO: Implementar envío de email
  Future<void> enviarEmailResumen({
    required int socioId,
    required String email,
    required double saldo,
    required double rdaPendiente,
  }) async {
    // TODO: Implementar lógica de envío de email
    await Future.delayed(const Duration(milliseconds: 500));

    // Aquí se podría:
    // 1. Llamar a una Cloud Function de Firebase
    // 2. Usar un servicio de email (SendGrid, etc.)
    // 3. Generar PDF con el detalle de la cuenta

    print('Email enviado a $email para socio $socioId');
    print('Saldo: $saldo, RDA Pendiente: $rdaPendiente');
  }
}
