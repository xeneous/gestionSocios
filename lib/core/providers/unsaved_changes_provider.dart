import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flag global: hay un formulario con cambios sin guardar en pantalla.
///
/// Lo usa el router para no expulsar al usuario a /login si se pierde la
/// sesión mientras está cargando datos (ver app_router.dart), en vez de
/// eso se ofrece reautenticación in-place sin perder el formulario.
class UnsavedChangesNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final unsavedChangesProvider =
    NotifierProvider<UnsavedChangesNotifier, bool>(UnsavedChangesNotifier.new);
