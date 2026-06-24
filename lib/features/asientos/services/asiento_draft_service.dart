import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste un borrador del formulario de asiento en almacenamiento local
/// (localStorage en web) para que no se pierda si el usuario es expulsado
/// por una sesión vencida antes de guardar.
class AsientoDraftService {
  static String keyNuevo() => 'asiento_draft_new';

  static String keyEdicion(int asiento, int anioMes, int tipoAsiento) =>
      'asiento_draft_edit_${asiento}_${anioMes}_$tipoAsiento';

  Future<void> saveDraft(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> loadDraft(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraft(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
