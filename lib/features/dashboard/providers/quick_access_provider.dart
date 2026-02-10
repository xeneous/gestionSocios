import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quick_access_item.dart';

const _prefsKey = 'quick_access_ids';

final quickAccessProvider =
    NotifierProvider<QuickAccessNotifier, List<String>>(
  QuickAccessNotifier.new,
);

class QuickAccessNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return defaultQuickAccessIds;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> save(List<String> ids) async {
    state = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, ids);
  }

  Future<void> toggle(String id) async {
    final current = [...state];
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    await save(current);
  }
}
