import 'package:universal_html/html.dart' as html;

/// Abre la ruta indicada en una nueva pestaña del navegador.
void abrirEnNuevaPestana(String ruta) {
  final origin = html.window.location.origin;
  html.window.open('$origin$ruta', '_blank');
}
