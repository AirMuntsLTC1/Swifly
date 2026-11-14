import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small JSON files kept on the phone. The app reads them first when it opens,
/// so people and follow lists show straight away, then the server refreshes them.
class LocalCache {
  LocalCache._();

  static Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/cache_$name.json');
  }

  static Future<void> save(String name, Object data) async {
    try {
      final f = await _file(name);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(data), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }

  /// The saved value, or null if there is none or it cannot be read.
  static Future<dynamic> load(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// Removes every saved cache file (used on sign out).
  static Future<void> clear() async {
    try {
      final dir = await getApplicationSupportDirectory();
      for (final entity in dir.listSync()) {
        if (entity is File && entity.path.contains('/cache_')) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }
}
