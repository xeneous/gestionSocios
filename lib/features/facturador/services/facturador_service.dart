import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facturacion_previa_model.dart';

class FacturadorService {
  final SupabaseClient _supabase;

  FacturadorService(this._supabase);

  /// Obtiene la vista previa de facturación para socios A, T y V (con seguro MP)
  Future<ResumenFacturacion> obtenerVistaPrevia({
    required List<PeriodoFacturacion> periodos,
  }) async {
    // 1. Obtener todos los socios elegibles (A, T, V) con paginación
    final socios = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int offset = 0;
    bool hasMore = true;

    while (hasMore) {
      final sociosResponse = await _supabase
          .from('socios')
          .select('id, apellido, nombre, grupo, residente, paga_seguro_mp, categoria_residente')
          .inFilter('grupo', ['A', 'T', 'V'])
          .eq('activo', true)
          .order('apellido')
          .range(offset, offset + pageSize - 1);

      final rows = sociosResponse as List<dynamic>;
      socios.addAll(rows.cast<Map<String, dynamic>>());
      hasMore = rows.length == pageSize;
      offset += pageSize;
    }

    if (socios.isEmpty) {
      return ResumenFacturacion(items: [], totalSocios: 0, totalCuotas: 0, totalImporte: 0.0);
    }

    // 2. Cargar categorías de residente en batch (tabla chica)
    final categoriasResponse = await _supabase
        .from('categorias_residente')
        .select('codigo, porcentaje_descuento');
    final categoriasMap = <String, double>{};
    for (final cat in categoriasResponse as List) {
      categoriasMap[cat['codigo'] as String] =
          (cat['porcentaje_descuento'] as num).toDouble();
    }

    // 3. Obtener valores de cuota social para todos los períodos (batch)
    final valoresMap = await _obtenerValoresCuotaSocialBatch(periodos);

    // 4. Obtener cuotas existentes (paginado)
    final socioIds = socios.map((s) => s['id'] as int).toList();
    final anioMeses = periodos.map((p) => p.anioMes.toString()).toList();
    final cuotasExistentesSet = <String>{};

    const cuotasPageSize = 1000;
    int cuotasOffset = 0;
    bool cuotasHasMore = true;

    while (cuotasHasMore) {
      final cuotasResponse = await _supabase
          .from('cuentas_corrientes')
          .select('socio_id, documento_numero')
          .inFilter('socio_id', socioIds)
          .inFilter('tipo_comprobante', ['CS', 'CRP', 'CRB'])
          .inFilter('documento_numero', anioMeses)
          .range(cuotasOffset, cuotasOffset + cuotasPageSize - 1);

      for (final row in cuotasResponse as List) {
        cuotasExistentesSet.add('${row['socio_id']}-${row['documento_numero']}');
      }
      cuotasHasMore = (cuotasResponse).length == cuotasPageSize;
      cuotasOffset += cuotasPageSize;
    }

    // 5. Calcular items
    final items = <ItemFacturacionPrevia>[];
    int totalCuotas = 0;
    double totalImporte = 0.0;

    for (final socio in socios) {
      final socioId = socio['id'] as int;
      final grupo = socio['grupo'] as String;
      final residente = socio['residente'] as bool? ?? false;
      final pagaSeguroMp = socio['paga_seguro_mp'] as bool? ?? false;

      if (grupo == 'V' && !pagaSeguroMp) continue;

      final usarTarifaResidente = residente || (grupo == 'V' && pagaSeguroMp);

      // Porcentaje de descuento según categoría de residente
      final categoriaResidente = socio['categoria_residente'] as String?;
      final porcentajeDescuento = (usarTarifaResidente && categoriaResidente != null)
          ? (categoriasMap[categoriaResidente] ?? 0.0)
          : 0.0;

      final mesesFaltantes = periodos.where((p) {
        return !cuotasExistentesSet.contains('$socioId-${p.anioMes}');
      }).toList();

      if (mesesFaltantes.isEmpty) continue;

      double importeSocio = 0.0;
      for (final periodo in mesesFaltantes) {
        final valor = valoresMap[periodo.anioMes];
        if (valor != null) {
          double base = usarTarifaResidente ? valor['residente']! : valor['noResidente']!;
          if (porcentajeDescuento >= 100) {
            base = 0;
          } else if (porcentajeDescuento > 0) {
            base = base * (100 - porcentajeDescuento) / 100;
          }
          importeSocio += base;
        }
      }

      items.add(ItemFacturacionPrevia(
        socioId: socioId,
        socioNombre: '${socio['apellido']} ${socio['nombre']}'.trim(),
        socioGrupo: grupo,
        residente: usarTarifaResidente,
        porcentajeDescuento: porcentajeDescuento,
        mesesFaltantes: mesesFaltantes,
        importeTotal: importeSocio,
      ));

      totalCuotas += mesesFaltantes.length;
      totalImporte += importeSocio;
    }

    return ResumenFacturacion(
      items: items,
      totalSocios: items.length,
      totalCuotas: totalCuotas,
      totalImporte: totalImporte,
    );
  }

  String _getConcepto(double porcentajeDescuento) {
    if (porcentajeDescuento >= 100) return 'CRB';
    if (porcentajeDescuento > 0) return 'CRP';
    return 'CS';
  }

  /// Genera las cuotas sociales masivamente usando TRANSACCIONES BATCH
  Future<void> generarCuotasMasivas({
    required ResumenFacturacion resumen,
    required Function(int current, int total) onProgress,
  }) async {
    // Obtener valores de cuota social (EN BATCH)
    final todosLosPeriodos = resumen.items
        .expand((item) => item.mesesFaltantes)
        .toSet()
        .toList();
    final valoresMap = await _obtenerValoresCuotaSocialBatch(todosLosPeriodos);

    // Preparar todos los headers y detalles para insert batch
    final headers = <Map<String, dynamic>>[];
    final detallesPorHeader = <List<Map<String, dynamic>>>[];

    for (final item in resumen.items) {
      for (final periodo in item.mesesFaltantes) {
        double base = item.residente
            ? valoresMap[periodo.anioMes]!['residente']!
            : valoresMap[periodo.anioMes]!['noResidente']!;

        // Aplicar descuento unificado según porcentajeDescuento
        double importe;
        if (item.porcentajeDescuento >= 100) {
          importe = 0;
        } else if (item.porcentajeDescuento > 0) {
          importe = base * (100 - item.porcentajeDescuento) / 100;
        } else {
          importe = base;
        }

        final concepto = _getConcepto(item.porcentajeDescuento);
        final fecha = DateTime(periodo.anio, periodo.mes, 1);
        final ultimoDia = DateTime(periodo.anio, periodo.mes + 1, 0);

        headers.add({
          'socio_id': item.socioId,
          'entidad_id': 0,
          'fecha': fecha.toIso8601String(),
          'tipo_comprobante': concepto, // CS, CRP o CRB según descuento
          'documento_numero': periodo.anioMes.toString(),
          'importe': importe,
          'cancelado': 0,
          'vencimiento': ultimoDia.toIso8601String(),
        });

        detallesPorHeader.add([
          {
            'item': 1,
            'concepto': 'CS',
            'cantidad': 1,
            'importe': importe,
          }
        ]);
      }
    }

    // INSERT en lotes de 100 para no sobrecargar
    const batchSize = 100;
    int procesados = 0;
    final total = headers.length;

    for (int i = 0; i < headers.length; i += batchSize) {
      final end = (i + batchSize < headers.length) ? i + batchSize : headers.length;
      final batch = headers.sublist(i, end);

      // Insertar headers y obtener los IDs
      final insertedHeaders = await _supabase
          .from('cuentas_corrientes')
          .insert(batch)
          .select('idtransaccion');

      // Insertar detalles correspondientes
      final detallesParaInsertar = <Map<String, dynamic>>[];
      for (int j = 0; j < insertedHeaders.length; j++) {
        final idtransaccion = insertedHeaders[j]['idtransaccion'] as int;
        final detalles = detallesPorHeader[i + j];

        for (final detalle in detalles) {
          detallesParaInsertar.add({
            ...detalle,
            'idtransaccion': idtransaccion,
          });
        }
      }

      if (detallesParaInsertar.isNotEmpty) {
        await _supabase
            .from('detalle_cuentas_corrientes')
            .insert(detallesParaInsertar);
      }

      procesados += batch.length;
      onProgress(procesados, total);
    }
  }

  /// Obtiene los valores de cuota social para los períodos (OPTIMIZADO - EN BATCH)
  Future<Map<int, Map<String, double>>> _obtenerValoresCuotaSocialBatch(
    List<PeriodoFacturacion> periodos,
  ) async {
    final map = <int, Map<String, double>>{};

    // Obtener todos los períodos de valores_cuota_social en una sola query
    final response = await _supabase
        .from('valores_cuota_social')
        .select('anio_mes_inicio, anio_mes_cierre, valor_residente, valor_titular')
        .order('anio_mes_inicio');

    final rangos = response as List<dynamic>;

    // Para cada período solicitado, buscar el rango que lo contenga
    for (final periodo in periodos) {
      bool encontrado = false;

      for (final rango in rangos) {
        final inicio = rango['anio_mes_inicio'] as int;
        final cierre = rango['anio_mes_cierre'] as int;

        if (periodo.anioMes >= inicio && periodo.anioMes <= cierre) {
          map[periodo.anioMes] = {
            'residente': (rango['valor_residente'] as num).toDouble(),
            'noResidente': (rango['valor_titular'] as num).toDouble(),
          };
          encontrado = true;
          break;
        }
      }

      if (!encontrado) {
        throw Exception(
          'No hay valor de cuota social configurado para ${periodo.nombreMes} ${periodo.anio}',
        );
      }
    }

    return map;
  }
}
