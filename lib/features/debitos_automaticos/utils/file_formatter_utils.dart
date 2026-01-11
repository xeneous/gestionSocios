/// Utilidades para formateo de archivos de presentación de tarjetas
class FileFormatterUtils {
  /// Formatea una fecha en formato DDMMYY
  static String formatFechaDDMMYY(DateTime fecha) {
    final day = fecha.day.toString().padLeft(2, '0');
    final month = fecha.month.toString().padLeft(2, '0');
    final year = fecha.year.toString().substring(2, 4);
    return '$day$month$year';
  }

  /// Formatea una fecha en formato MM/YY (con barra diagonal)
  static String formatFechaMMYY(DateTime fecha) {
    final month = fecha.month.toString().padLeft(2, '0');
    final year = fecha.year.toString().substring(2, 4);
    return '$month/$year';
  }

  /// Formatea un número con padding de ceros a la izquierda
  static String formatNumeroConPadding(int valor, int length) {
    return valor.toString().padLeft(length, '0');
  }

  /// Formatea un importe multiplicándolo por 100 y agregando padding
  /// Ejemplo: 32.50 -> "000000003250000" (15 dígitos)
  /// Ejemplo: 14.33 -> "00000001433" (11 dígitos)
  /// Convierte el importe a centavos (sin decimales)
  static String formatImporte(double importe, int length) {
    final importeCentavos = (importe * 100).round();
    return formatNumeroConPadding(importeCentavos, length);
  }

  /// Limpia y formatea un número de tarjeta (elimina espacios y guiones)
  static String formatTarjeta(String numeroTarjeta) {
    return numeroTarjeta.replaceAll(RegExp(r'[\s-]'), '');
  }

  /// Agrega espacios a la derecha hasta completar la longitud deseada
  static String padRight(String texto, int length) {
    return texto.padRight(length, ' ');
  }

  /// Agrega espacios a la izquierda hasta completar la longitud deseada
  static String padLeft(String texto, int length) {
    return texto.padLeft(length, ' ');
  }

  /// Genera una línea con espacios hasta la longitud especificada
  static String espacios(int length) {
    return ' ' * length;
  }

  /// Valida que una línea tenga exactamente la longitud especificada
  static bool validarLongitudLinea(String linea, int longitudEsperada) {
    return linea.length == longitudEsperada;
  }
}
