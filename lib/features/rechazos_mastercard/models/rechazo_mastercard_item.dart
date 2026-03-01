class RechazoMastercardItem {
  final int socioId;
  final int entidadId;
  final String tarjetaNueva;     // col 2: número informado por el banco
  final String tarjetaActual;    // col 3: número que tenemos en Supabase
  final double importe;          // col 7
  final String motivo;           // col 8
  final DateTime fechaPresentacion; // ingresada por el usuario

  RechazoMastercardItem({
    required this.socioId,
    required this.entidadId,
    required this.tarjetaNueva,
    required this.tarjetaActual,
    required this.importe,
    required this.motivo,
    required this.fechaPresentacion,
  });

  /// Col 8 empieza con "Observado" → actualizar tarjeta en sistema
  bool get esObservado => motivo.toLowerCase().startsWith('observado');

  /// Col 8 empieza con número → rechazo, crear RDA en CC
  bool get esRechazo => !esObservado;

  /// YYYYMM derivado de la fecha de presentación (para buscar el DA en CC)
  String get documentoNumero {
    final yyyy = fechaPresentacion.year;
    final mm = fechaPresentacion.month.toString().padLeft(2, '0');
    return '$yyyy$mm';
  }

  /// Parsea una línea CSV (separada por ';') del archivo Mastercard.
  /// [fechaPresentacion] es la fecha ingresada por el usuario.
  static RechazoMastercardItem? parsearLinea(
      String linea, DateTime fechaPresentacion) {
    final partes = linea.trim().split(';');
    if (partes.length < 8) return null;

    final idStr = partes[0].trim();
    if (idStr.isEmpty) return null;

    final idCompleto = int.tryParse(idStr);
    if (idCompleto == null || idCompleto == 0) return null;

    // Último dígito = entidad, resto / 10 = socioId
    final entidadId = idCompleto % 10;
    final socioId = idCompleto ~/ 10;
    if (socioId == 0) return null;

    final tarjetaNueva = partes[1].trim();
    final tarjetaActual = partes[2].trim();
    final importe = double.tryParse(partes[6].trim()) ?? 0.0;
    final motivo = partes[7].trim();
    if (motivo.isEmpty) return null;

    return RechazoMastercardItem(
      socioId: socioId,
      entidadId: entidadId,
      tarjetaNueva: tarjetaNueva,
      tarjetaActual: tarjetaActual,
      importe: importe,
      motivo: motivo,
      fechaPresentacion: fechaPresentacion,
    );
  }

  /// Parsea el contenido completo del archivo y retorna todos los ítems válidos.
  static List<RechazoMastercardItem> parsearArchivo(
      String contenido, DateTime fechaPresentacion) {
    final lineas = contenido.split('\n');
    final items = <RechazoMastercardItem>[];
    for (final linea in lineas) {
      final item = parsearLinea(linea, fechaPresentacion);
      if (item != null) items.add(item);
    }
    return items;
  }
}

// ---------------------------------------------------------------------------
// Resultado del cruce con CC
// ---------------------------------------------------------------------------

class RechazoMastercardResultado {
  final RechazoMastercardItem item;
  final int? idtransaccionDA; // null si no se encontró el DA (solo aplica a rechazos)
  final String? socioNombre;
  bool seleccionado;

  RechazoMastercardResultado({
    required this.item,
    required this.idtransaccionDA,
    required this.socioNombre,
    this.seleccionado = true,
  });

  /// Para observados siempre "encontrado" (no necesitan DA en CC).
  /// Para rechazos, depende de si se encontró el DA.
  bool get daEncontrado =>
      item.esObservado ? true : idtransaccionDA != null;
}
