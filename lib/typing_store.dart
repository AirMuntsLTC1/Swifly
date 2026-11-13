import 'dart:async';

import 'package:flutter/foundation.dart';

/// Who is typing a comment on each post right now. An entry clears itself
/// automatically if no update arrives, so a dropped "stopped typing" event
/// can't leave the indicator stuck on screen.
class TypingStore extends ChangeNotifier {
  TypingStore._();
  static final TypingStore instance = TypingStore._();

  static const Duration _expiry = Duration(seconds: 6);

  final Map<String, Map<String, String>> _names = {};
  final Map<String, Map<String, Timer>> _timers = {};

  /// Display names of people typing on [postId].
  List<String> namesFor(String postId) =>
      List.unmodifiable(_names[postId]?.values ?? const <String>[]);

  void setTyping(String postId, String handle, String name, bool typing) {
    final names = _names.putIfAbsent(postId, () => <String, String>{});
    final timers = _timers.putIfAbsent(postId, () => <String, Timer>{});

    timers.remove(handle)?.cancel();
    if (!typing) {
      if (names.remove(handle) != null) notifyListeners();
      return;
    }

    final wasTyping = names.containsKey(handle);
    names[handle] = name;
    timers[handle] = Timer(_expiry, () => setTyping(postId, handle, name, false));
    if (!wasTyping) notifyListeners();
  }
}


