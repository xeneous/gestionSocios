class RechazoDAItem {
  final String tarjeta;             // pos 27, len 16
  final DateTime fechaPresentacion; // pos 51, len 6 (DDMMAA)
  final double importe;             // pos 63, len 15 / 100
  final int socioId;                // pos 88, len 6
  final int entidadId;              // pos 95, len 1
  final String motivoCodigo;        // primeros 3 chars de pos 130
  final String motivoDescripcion;   // chars 4..32 de pos 130 (trim)

  RechazoDAItem({
    required this.tarjeta,
    required this.fechaPresentacion,
    required this.importe,
    required this.socioId,
    required this.entidadId,
    required this.motivoCodigo,
    required this.motivoDescripcion,
  });

  /// YYYYMM derivado de la fecha de presentación (para buscar el DA)
  String get documentoNumero {
    final yyyy = fechaPresentacion.year;
    final mm = fechaPresentacion.month.toString().padLeft(2, '0');
    return '$yyyy$mm';
  }

  String get motivoCompleto =>
      motivoDescripcion.isNotEmpty ? '$motivoCodigo $motivoDescripcion' : motivoCodigo;

  /// Parsea una línea del archivo RDEBLIQC y retorna un RechazoDAItem,
  /// o null si la línea no es un rechazo real.
  static RechazoDAItem? parsearLinea(String linea) {
    // Solo procesar registros de tipo '1'
    if (!linea.startsWith('1')) return null;
    if (linea.length < 162) return null;

    // pos 130, len 32 (0-indexed: 129..161)
    final motivoRaw = linea.substring(129, 161);
    final motivoTrim = motivoRaw.trim();

    // '000' = débito acreditado correctamente → no es rechazo
    if (motivoTrim.isEmpty || motivoTrim == '000') return null;

    // Extraer campos (posiciones 1-indexed → substring 0-indexed)
    final tarjeta = linea.substring(26, 42).trim();           // pos 27, len 16
    final fechaStr = linea.substring(50, 56);                  // pos 51, len 6 DDMMAA
    final importeStr = linea.substring(62, 77);               // pos 63, len 15
    final socioStr = linea.substring(87, 93);                  // pos 88, len 6
    final entidadStr = linea.substring(94, 95);               // pos 95, len 1

    // Parsear fecha DDMMAA
    final dd = int.tryParse(fechaStr.substring(0, 2)) ?? 1;
    final mm = int.tryParse(fechaStr.substring(2, 4)) ?? 1;
    final yy = int.tryParse(fechaStr.substring(4, 6)) ?? 0;
    final yyyy = 2000 + yy;
    final fechaPresentacion = DateTime(yyyy, mm, dd);

    // Parsear importe (dividir por 100)
    final importeInt = int.tryParse(importeStr.trim()) ?? 0;
    final importe = importeInt / 100.0;

    // Parsear socio y entidad
    final socioId = int.tryParse(socioStr.trim()) ?? 0;
    final entidadId = int.tryParse(entidadStr.trim()) ?? 0;

    // Separar código (3 chars) y descripción del motivo
    final motivoCodigo = motivoTrim.length >= 3 ? motivoTrim.substring(0, 3) : motivoTrim;
    final motivoDescripcion = motivoTrim.length > 3 ? motivoTrim.substring(3).trim() : '';

    return RechazoDAItem(
      tarjeta: tarjeta,
      fechaPresentacion: fechaPresentacion,
      importe: importe,
      socioId: socioId,
      entidadId: entidadId,
      motivoCodigo: motivoCodigo,
      motivoDescripcion: motivoDescripcion,
    );
  }

  /// Parsea el contenido completo del archivo y retorna solo los rechazos reales.
  static List<RechazoDAItem> parsearArchivo(String contenido) {
    final lineas = contenido.split('\n');
    final rechazos = <RechazoDAItem>[];
    for (final linea in lineas) {
      final item = parsearLinea(linea);
      if (item != null) rechazos.add(item);
    }
    return rechazos;
  }
}

/// Resultado de cruzar un RechazoDAItem con la CC (DA encontrado o no)
class RechazoDAResultado {
  final RechazoDAItem rechazo;
  final int? idtransaccionDA;   // idtransaccion del DA encontrado en CC (null = no encontrado)
  final String? socioNombre;    // nombre del socio para mostrar
  bool seleccionado;

  RechazoDAResultado({
    required this.rechazo,
    required this.idtransaccionDA,
    required this.socioNombre,
    this.seleccionado = true,
  });

  bool get daEncontrado => idtransaccionDA != null;
}
