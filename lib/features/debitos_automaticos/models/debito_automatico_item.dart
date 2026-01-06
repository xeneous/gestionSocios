class DebitoAutomaticoItem {
  final int socioId;
  final String apellido;
  final String nombre;
  final String? numeroTarjeta;
  final double importe;
  final int idtransaccion;
  final String tipoComprobante;
  final String documentoNumero;

  DebitoAutomaticoItem({
    required this.socioId,
    required this.apellido,
    required this.nombre,
    this.numeroTarjeta,
    required this.importe,
    required this.idtransaccion,
    required this.tipoComprobante,
    required this.documentoNumero,
  });

  /// Valida si el número de tarjeta tiene 16 dígitos
  bool get tarjetaValida {
    if (numeroTarjeta == null || numeroTarjeta!.isEmpty) {
      return false;
    }
    // Remover espacios y guiones
    final cleaned = numeroTarjeta!.replaceAll(RegExp(r'[\s-]'), '');
    return cleaned.length == 16 && int.tryParse(cleaned) != null;
  }

  /// Retorna el número de tarjeta enmascarado (XXXX-XXXX-XXXX-1234)
  String get numeroTarjetaEnmascarado {
    if (numeroTarjeta == null || numeroTarjeta!.isEmpty) {
      return 'Sin tarjeta';
    }
    final cleaned = numeroTarjeta!.replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.length >= 4) {
      final ultimos4 = cleaned.substring(cleaned.length - 4);
      return 'XXXX-XXXX-XXXX-$ultimos4';
    }
    return 'Tarjeta inválida';
  }

  factory DebitoAutomaticoItem.fromJson(Map<String, dynamic> json) {
    return DebitoAutomaticoItem(
      socioId: json['socio_id'] as int,
      apellido: json['apellido'] as String,
      nombre: json['nombre'] as String,
      numeroTarjeta: json['numero_tarjeta'] as String?,
      importe: (json['importe'] as num).toDouble(),
      idtransaccion: json['idtransaccion'] as int,
      tipoComprobante: json['tipo_comprobante'] as String,
      documentoNumero: json['documento_numero'] as String,
    );
  }
}
