import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quick_access_item.dart';
import '../../auth/presentation/providers/auth_provider.dart';

final quickAccessProvider =
    NotifierProvider<QuickAccessNotifier, List<String>>(
  QuickAccessNotifier.new,
);

class QuickAccessNotifier extends Notifier<List<String>> {
  String _prefsKey(String userId) => 'quick_access_ids_$userId';

  @override
  List<String> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      _load(user.id);
    }
    return defaultQuickAccessIds;
  }

  Future<void> _load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey(userId));
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> save(List<String> ids) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    state = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey(user.id), ids);
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
