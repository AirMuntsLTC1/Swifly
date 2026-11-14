import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'local_cache.dart';

/// People you just followed back. They appear as "New followers" in Messages
/// until you send the first message. Saved on the phone for each account.
class NewConnections extends ChangeNotifier {
  NewConnections._();
  static final NewConnections instance = NewConnections._();

  final Set<String> _handles = <String>{};

  /// Newest first.
  List<String> get handles => _handles.toList().reversed.toList();

  bool contains(String handle) => _handles.contains(handle);

  String get _key => 'new_connections_${DatabaseService.instance.myId ?? 'anon'}';

  Future<void> load() async {
    final saved = await LocalCache.load(_key);
    if (saved is List) {
      _handles
        ..clear()
        ..addAll([for (final h in saved) '$h']);
      notifyListeners();
    }
  }

  void add(String handle) {
    if (_handles.add(handle)) {
      _save();
      notifyListeners();
    }
  }

  void remove(String handle) {
    if (_handles.remove(handle)) {
      _save();
      notifyListeners();
    }
  }

  void clear() {
    _handles.clear();
    notifyListeners();
  }

  void _save() => LocalCache.save(_key, _handles.toList());
}
