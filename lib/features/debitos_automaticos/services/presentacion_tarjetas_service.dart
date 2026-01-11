import '../models/debito_automatico_item.dart';
import '../models/presentacion_config.dart';
import '../utils/file_formatter_utils.dart';

/// Servicio para generar archivos de presentación de débitos automáticos
class PresentacionTarjetasService {
  /// Genera el archivo Visamov.txt para presentación de débitos VISA
  /// 
  /// Formato: 80 caracteres por línea
  /// - Línea de encabezado de lote cada 99 registros
  /// - Líneas de detalle con tarjeta, cupón, importe y referencia
  String generarArchivoVisa(
    List<DebitoAutomaticoItem> items,
    DateTime fechaLimite,
  ) {
    final buffer = StringBuffer();
    final itemsValidos = items.where((item) => item.tarjetaValida).toList();

    if (itemsValidos.isEmpty) {
      return '';
    }

    // Ordenar por socio_id
    itemsValidos.sort((a, b) => a.socioId.compareTo(b.socioId));

    // Procesar en lotes de 99
    int loteActual = 0;
    int cuponGlobal = 0;

    for (int i = 0; i < itemsValidos.length; i += PresentacionConfig.visaMaxItemsLote) {
      final loteInicio = i;
      final loteFin = (i + PresentacionConfig.visaMaxItemsLote < itemsValidos.length)
          ? i + PresentacionConfig.visaMaxItemsLote
          : itemsValidos.length;

      final itemsLote = itemsValidos.sublist(loteInicio, loteFin);
      final cantidadItemsLote = itemsLote.length;

      // Calcular total del lote
      final totalLote = itemsLote.fold<double>(0.0, (sum, item) => sum + item.importe);

      // Escribir encabezado de lote
      buffer.writeln(_generarEncabezadoLoteVisa(
        fechaLimite: fechaLimite,
        numeroLote: loteActual,
        cantidadItems: cantidadItemsLote,
        totalLote: totalLote,
      ));

      // Escribir items del lote
      for (var item in itemsLote) {
        cuponGlobal++;
        buffer.writeln(_generarDetalleVisa(
          item: item,
          numeroCupon: cuponGlobal,
          fechaLimite: fechaLimite,
        ));
      }

      loteActual++;
    }

    return buffer.toString();
  }

  /// Genera el archivo Pesos.txt para presentación de débitos MASTERCARD
  /// 
  /// Formato: 129 caracteres por línea
  /// - UNA línea de encabezado con totales al inicio
  /// - Líneas de detalle con tarjeta, referencia, importe y período
  String generarArchivoMastercard(
    List<DebitoAutomaticoItem> items,
    DateTime fechaLimite,
  ) {
    final buffer = StringBuffer();
    final itemsValidos = items.where((item) => item.tarjetaValida).toList();

    if (itemsValidos.isEmpty) {
      return '';
    }

    // Ordenar por socio_id
    itemsValidos.sort((a, b) => a.socioId.compareTo(b.socioId));

    // Calcular totales
    final cantidadTotal = itemsValidos.length;
    final importeTotal = itemsValidos.fold<double>(0.0, (sum, item) => sum + item.importe);

    // Escribir encabezado del archivo (solo UNA vez)
    buffer.writeln(_generarEncabezadoMastercard(
      fechaLimite: fechaLimite,
      cantidadTotal: cantidadTotal,
      importeTotal: importeTotal,
    ));

    // Escribir todos los detalles
    for (var item in itemsValidos) {
      buffer.writeln(_generarDetalleMastercard(
        item: item,
        fechaLimite: fechaLimite,
      ));
    }

    return buffer.toString();
  }

  // ========================================================================
  // MÉTODOS PRIVADOS - VISA
  // ========================================================================

  /// Genera línea de encabezado de lote para VISA (80 caracteres)
  String _generarEncabezadoLoteVisa({
    required DateTime fechaLimite,
    required int numeroLote,
    required int cantidadItems,
    required double totalLote,
  }) {
    final linea = StringBuffer();

    linea.write('0DB'); // Posiciones 1-3
    linea.write(FileFormatterUtils.formatFechaDDMMYY(fechaLimite)); // 4-9
    linea.write(PresentacionConfig.visaCodigo); // 10-15: "029999"
    linea.write(FileFormatterUtils.formatNumeroConPadding(numeroLote, 4)); // 16-19
    linea.write(FileFormatterUtils.espacios(7)); // 20-26
    linea.write(PresentacionConfig.visaEstablecimiento); // 27-40
    linea.write(FileFormatterUtils.formatNumeroConPadding(cantidadItems, 2)); // 41-42
    linea.write(FileFormatterUtils.formatImporte(totalLote, 15)); // 43-57
    linea.write(' 0000'); // 58-62
    linea.write(FileFormatterUtils.espacios(18)); // 63-80

    final resultado = linea.toString();
    
    // Validar longitud
    if (!FileFormatterUtils.validarLongitudLinea(resultado, PresentacionConfig.visaLongitudLinea)) {
      throw Exception('Error: Línea de encabezado VISA tiene ${resultado.length} caracteres, esperados ${PresentacionConfig.visaLongitudLinea}');
    }

    return resultado;
  }

  /// Genera línea de detalle para VISA (80 caracteres)
  String _generarDetalleVisa({
    required DebitoAutomaticoItem item,
    required int numeroCupon,
    required DateTime fechaLimite,
  }) {
    final linea = StringBuffer();
    final tarjeta = FileFormatterUtils.formatTarjeta(item.numeroTarjeta ?? '');

    linea.write(FileFormatterUtils.espacios(3)); // 1-3
    linea.write(tarjeta.padLeft(16, '0')); // 4-19: número de tarjeta (16 dígitos)
    linea.write(' '); // 20
    linea.write(FileFormatterUtils.formatNumeroConPadding(numeroCupon, 8)); // 21-28
    linea.write(FileFormatterUtils.formatFechaDDMMYY(fechaLimite)); // 29-34
    linea.write(FileFormatterUtils.espacios(8)); // 35-42
    linea.write(FileFormatterUtils.formatImporte(item.importe, 15)); // 43-57
    linea.write(FileFormatterUtils.espacios(7)); // 58-64
    // Socio ID con entidad: se multiplica por 10 y se agrega 0 (entidad socios)
    final socioIdConEntidad = item.socioId * 10;
    linea.write(FileFormatterUtils.formatNumeroConPadding(socioIdConEntidad, 15)); // 65-79
    linea.write(' '); // 80

    final resultado = linea.toString();
    
    // Validar longitud
    if (!FileFormatterUtils.validarLongitudLinea(resultado, PresentacionConfig.visaLongitudLinea)) {
      throw Exception('Error: Línea de detalle VISA tiene ${resultado.length} caracteres, esperados ${PresentacionConfig.visaLongitudLinea}');
    }

    return resultado;
  }

  // ========================================================================
  // MÉTODOS PRIVADOS - MASTERCARD
  // ========================================================================

  /// Genera línea de encabezado para MASTERCARD (129 caracteres)
  String _generarEncabezadoMastercard({
    required DateTime fechaLimite,
    required int cantidadTotal,
    required double importeTotal,
  }) {
    final linea = StringBuffer();

    linea.write(PresentacionConfig.mastercardHeader); // 1-9: "066812811"
    linea.write(FileFormatterUtils.formatFechaDDMMYY(fechaLimite)); // 10-15
    linea.write(FileFormatterUtils.formatNumeroConPadding(cantidadTotal, 7)); // 16-22
    linea.write(FileFormatterUtils.formatImporte(importeTotal, 15)); // 23-37
    linea.write(FileFormatterUtils.espacios(92)); // 38-129

    final resultado = linea.toString();
    
    // Validar longitud
    if (!FileFormatterUtils.validarLongitudLinea(resultado, PresentacionConfig.mastercardLongitudLinea)) {
      throw Exception('Error: Línea de encabezado MASTERCARD tiene ${resultado.length} caracteres, esperados ${PresentacionConfig.mastercardLongitudLinea}');
    }

    return resultado;
  }

  /// Genera línea de detalle para MASTERCARD (129 caracteres)
  String _generarDetalleMastercard({
    required DebitoAutomaticoItem item,
    required DateTime fechaLimite,
  }) {
    final linea = StringBuffer();
    final tarjeta = FileFormatterUtils.formatTarjeta(item.numeroTarjeta ?? '');

    linea.write(PresentacionConfig.mastercardDetalle); // 1-9: "066812812"
    linea.write(tarjeta.padLeft(16, '0')); // 10-25: número de tarjeta (16 dígitos)
    // Socio ID con entidad: se multiplica por 10 y se agrega 0 (entidad socios)
    final socioIdConEntidad = item.socioId * 10;
    linea.write(FileFormatterUtils.formatNumeroConPadding(socioIdConEntidad, 12)); // 26-37
    linea.write(PresentacionConfig.mastercardConstante); // 38-45: "00199901"
    linea.write(FileFormatterUtils.formatImporte(item.importe, 11)); // 46-56
    linea.write(FileFormatterUtils.formatFechaMMYY(fechaLimite)); // 57-61: "MM/YY"
    linea.write(FileFormatterUtils.espacios(68)); // 62-129 (68 espacios)

    final resultado = linea.toString();
    
    // Validar longitud
    if (!FileFormatterUtils.validarLongitudLinea(resultado, PresentacionConfig.mastercardLongitudLinea)) {
      throw Exception('Error: Línea de detalle MASTERCARD tiene ${resultado.length} caracteres, esperados ${PresentacionConfig.mastercardLongitudLinea}');
    }

    return resultado;
  }
}
