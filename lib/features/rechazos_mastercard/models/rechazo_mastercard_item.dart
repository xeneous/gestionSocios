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

  /// Clave de agrupación: todas las líneas de un mismo socio/entidad/período
  /// corresponden a un único DA combinado en cuenta corriente.
  String get grupoKey => '$entidadId|$socioId|$documentoNumero';

  /// Elimina el formato Excel CSV: ="12345" → 12345
  static String _limpiar(String valor) {
    String v = valor.trim();
    if (v.startsWith('="') && v.endsWith('"')) {
      v = v.substring(2, v.length - 1);
    }
    return v;
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

    final tarjetaNueva = _limpiar(partes[1]);
    final tarjetaActual = _limpiar(partes[2]);
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
  final int? idtransaccionCS; // idtransaccion de la CS original a revertir (null = no resuelta; no aplica a observados)
  final String? socioNombre;
  final String grupoKey;
  final bool grupoEncontrado; // true si TODAS las líneas del grupo matchearon (siempre true para observados)
  final int lineasEnGrupo;
  bool seleccionado;

  RechazoMastercardResultado({
    required this.item,
    required this.idtransaccionCS,
    required this.socioNombre,
    required this.grupoEncontrado,
    required this.lineasEnGrupo,
    String? grupoKey,
    this.seleccionado = true,
  }) : grupoKey = grupoKey ?? item.grupoKey;

  /// Para observados siempre "encontrado" (no necesitan DA en CC).
  /// Para rechazos, depende de si matchearon todas las líneas del grupo.
  bool get daEncontrado => item.esObservado ? true : grupoEncontrado;
  bool get esGrupoCombinado => !item.esObservado && lineasEnGrupo > 1;
}
