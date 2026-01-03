/// Utilidad para convertir números a letras en español (Argentina)
/// Soporta valores desde 0 hasta 999,999,999.99
class NumeroALetras {
  static const List<String> _unidades = [
    '',
    'uno',
    'dos',
    'tres',
    'cuatro',
    'cinco',
    'seis',
    'siete',
    'ocho',
    'nueve',
  ];

  static const List<String> _decenas = [
    '',
    '',
    'veinte',
    'treinta',
    'cuarenta',
    'cincuenta',
    'sesenta',
    'setenta',
    'ochenta',
    'noventa',
  ];

  static const List<String> _especiales = [
    'diez',
    'once',
    'doce',
    'trece',
    'catorce',
    'quince',
    'dieciséis',
    'diecisiete',
    'dieciocho',
    'diecinueve',
  ];

  static const List<String> _centenas = [
    '',
    'ciento',
    'doscientos',
    'trescientos',
    'cuatrocientos',
    'quinientos',
    'seiscientos',
    'setecientos',
    'ochocientos',
    'novecientos',
  ];

  /// Convierte un número decimal a texto en español
  /// Ejemplo: 1234.56 -> "mil doscientos treinta y cuatro pesos con cincuenta y seis centavos"
  static String convertir(double numero, {String moneda = 'pesos'}) {
    if (numero < 0) {
      return 'menos ${convertir(-numero, moneda: moneda)}';
    }

    // Separar parte entera y decimal
    final parteEntera = numero.floor();
    final parteDecimal = ((numero - parteEntera) * 100).round();

    // Convertir parte entera
    String textoEntero = _convertirEntero(parteEntera);

    // Manejar singular/plural de la moneda
    String textoMoneda = moneda;
    if (parteEntera == 1) {
      textoMoneda = moneda == 'pesos' ? 'peso' : moneda.substring(0, moneda.length - 1);
    }

    // Si hay centavos, agregarlos
    if (parteDecimal > 0) {
      String textoCentavos = _convertirEntero(parteDecimal);
      return '$textoEntero $textoMoneda con $textoCentavos centavos';
    } else {
      return '$textoEntero $textoMoneda';
    }
  }

  /// Convierte un número entero a texto
  static String _convertirEntero(int numero) {
    if (numero == 0) return 'cero';
    if (numero < 0) return 'menos ${_convertirEntero(-numero)}';

    String resultado = '';

    // Millones
    if (numero >= 1000000) {
      final millones = numero ~/ 1000000;
      if (millones == 1) {
        resultado += 'un millón';
      } else {
        resultado += '${_convertirGrupo(millones)} millones';
      }
      numero %= 1000000;
      if (numero > 0) resultado += ' ';
    }

    // Miles
    if (numero >= 1000) {
      final miles = numero ~/ 1000;
      if (miles == 1) {
        resultado += 'mil';
      } else {
        resultado += '${_convertirGrupo(miles)} mil';
      }
      numero %= 1000;
      if (numero > 0) resultado += ' ';
    }

    // Resto (0-999)
    if (numero > 0) {
      resultado += _convertirGrupo(numero);
    }

    return resultado.trim();
  }

  /// Convierte un grupo de 3 dígitos (0-999)
  static String _convertirGrupo(int numero) {
    if (numero == 0) return '';
    if (numero < 10) return _unidades[numero];
    if (numero < 20) return _especiales[numero - 10];

    String resultado = '';

    // Centenas
    final centena = numero ~/ 100;
    if (centena > 0) {
      // Caso especial: 100 se dice "cien", no "ciento"
      if (numero == 100) {
        return 'cien';
      }
      resultado += _centenas[centena];
      numero %= 100;
      if (numero > 0) resultado += ' ';
    }

    // Decenas y unidades
    if (numero >= 20) {
      final decena = numero ~/ 10;
      resultado += _decenas[decena];
      numero %= 10;
      if (numero > 0) resultado += ' y ${_unidades[numero]}';
    } else if (numero >= 10) {
      resultado += _especiales[numero - 10];
    } else if (numero > 0) {
      resultado += _unidades[numero];
    }

    return resultado;
  }
}
