import 'package:flutter/foundation.dart';

class StartupTimer {
  static final DateTime _start = DateTime.now();
  static void log(String step) {
    final elapsed = DateTime.now().difference(_start).inMilliseconds;
    debugPrint('[Swifly startup] $step (${elapsed}ms)');
  }
}
