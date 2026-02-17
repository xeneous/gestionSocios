import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facturacion_previa_model.dart';

class FacturadorService {
  final SupabaseClient _supabase;

  FacturadorService(this._supabase);

  /// Obtiene la vista previa de facturación para socios A y T
  Future<ResumenFacturacion> obtenerVistaPrevia({
    required List<PeriodoFacturacion> periodos,
  }) async {
    // 1. Obtener todos los socios con grupo A, T o V (con paginación)
    //    Los V solo se facturan si tienen paga_seguro_mp = true
    final socios = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int offset = 0;
    bool hasMore = true;

    while (hasMore) {
      final sociosResponse = await _supabase
          .from('socios')
          .select('id, apellido, nombre, grupo, residente, paga_seguro_mp, descuento_primer_anio, fecha_fin_descuento')
          .inFilter('grupo', ['A', 'T', 'V'])
          .order('apellido')
          .range(offset, offset + pageSize - 1);

      final rows = sociosResponse as List<dynamic>;
      socios.addAll(rows.cast<Map<String, dynamic>>());

      hasMore = rows.length == pageSize;
      offset += pageSize;
    }

    if (socios.isEmpty) {
      return ResumenFacturacion(
        items: [],
        totalSocios: 0,
        totalCuotas: 0,
        totalImporte: 0.0,
      );
    }

    // 2. Obtener valores de cuota social para todos los períodos (EN BATCH)
    final valoresMap = await _obtenerValoresCuotaSocialBatch(periodos);

    // 3. Obtener TODAS las cuotas existentes (con paginación para evitar límite de 1000)
    final socioIds = socios.map((s) => s['id'] as int).toList();
    final anioMeses = periodos.map((p) => p.anioMes.toString()).toList();

    final cuotasExistentesSet = <String>{};

    // Paginar en lotes de 1000 para evitar el límite de Supabase
    const cuotasPageSize = 1000;
    int cuotasOffset = 0;
    bool cuotasHasMore = true;

    while (cuotasHasMore) {
      final cuotasExistentesResponse = await _supabase
          .from('cuentas_corrientes')
          .select('socio_id, documento_numero')
          .inFilter('socio_id', socioIds)
          .eq('tipo_comprobante', 'CS')
          .inFilter('documento_numero', anioMeses)
          .range(cuotasOffset, cuotasOffset + cuotasPageSize - 1);

      final rows = cuotasExistentesResponse as List;

      for (final row in rows) {
        final socioId = row['socio_id'] as int;
        final docNum = row['documento_numero'] as String;
        cuotasExistentesSet.add('$socioId-$docNum');
      }

      cuotasHasMore = rows.length == cuotasPageSize;
      cuotasOffset += cuotasPageSize;
    }

    // 4. Para cada socio, detectar meses faltantes
    final items = <ItemFacturacionPrevia>[];
    int totalCuotas = 0;
    double totalImporte = 0.0;

    for (final socio in socios) {
      final socioId = socio['id'] as int;
      final grupo = socio['grupo'] as String;
      final residente = socio['residente'] as bool? ?? false;
      final pagaSeguroMp = socio['paga_seguro_mp'] as bool? ?? false;

      // Vitalicios: solo facturar si pagan seguro MP
      if (grupo == 'V' && !pagaSeguroMp) continue;

      // Vitalicios con seguro MP usan tarifa de residente
      final usarTarifaResidente = residente || (grupo == 'V' && pagaSeguroMp);

      final descuentoPrimerAnio = socio['descuento_primer_anio'] as bool? ?? false;
      final fechaFinDescuentoStr = socio['fecha_fin_descuento'] as String?;
      final fechaFinDescuento = (descuentoPrimerAnio && usarTarifaResidente && fechaFinDescuentoStr != null)
          ? DateTime.tryParse(fechaFinDescuentoStr)
          : null;
      final nombreCompleto =
          '${socio['apellido']} ${socio['nombre']}'.trim();

      // Filtrar solo los meses faltantes (búsqueda en Set = O(1))
      final mesesFaltantes = periodos.where((p) {
        final key = '$socioId-${p.anioMes}';
        return !cuotasExistentesSet.contains(key);
      }).toList();

      if (mesesFaltantes.isEmpty) continue;

      // Calcular importe total para este socio
      double importeSocio = 0.0;
      for (final periodo in mesesFaltantes) {
        final valor = valoresMap[periodo.anioMes];
        if (valor != null) {
          double importePeriodo = usarTarifaResidente ? valor['residente']! : valor['noResidente']!;
          // Aplicar descuento 50% solo si usa tarifa residente y el período está dentro del rango
          if (usarTarifaResidente && fechaFinDescuento != null) {
            final fechaPeriodo = DateTime(periodo.anio, periodo.mes, 1);
            if (fechaPeriodo.isBefore(fechaFinDescuento)) {
              importePeriodo = importePeriodo / 2;
            }
          }
          importeSocio += importePeriodo;
        }
      }

      items.add(ItemFacturacionPrevia(
        socioId: socioId,
        socioNombre: nombreCompleto,
        socioGrupo: grupo,
        residente: usarTarifaResidente,
        fechaFinDescuento: fechaFinDescuento,
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
        double importe = item.residente
            ? valoresMap[periodo.anioMes]!['residente']!
            : valoresMap[periodo.anioMes]!['noResidente']!;

        // Aplicar descuento 50% solo si el período específico lo tiene
        final tieneDescuento = item.periodoTieneDescuento(periodo);
        if (tieneDescuento) {
          importe = importe / 2;
        }

        // CRP = Cuota Residente Promoción (50%), CS = Cuota Social normal
        final concepto = tieneDescuento ? 'CRP' : 'CS';

        final fecha = DateTime(periodo.anio, periodo.mes, 1);
        final ultimoDia = DateTime(periodo.anio, periodo.mes + 1, 0);

        // Header
        headers.add({
          'socio_id': item.socioId,
          'entidad_id': 0,
          'fecha': fecha.toIso8601String(),
          'tipo_comprobante': 'CS',
          'documento_numero': periodo.anioMes.toString(),
          'importe': importe,
          'cancelado': 0,
          'vencimiento': ultimoDia.toIso8601String(),
        });

        // Detalle (lo insertaremos después con los IDs)
        detallesPorHeader.add([
          {
            'item': 1,
            'concepto': concepto,
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
