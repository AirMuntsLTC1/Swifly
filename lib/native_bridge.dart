import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:ffi/ffi.dart';

typedef _FormatNative = Int32 Function(Int64 value, Pointer<Utf8> out, Int32 outLen);
typedef _FormatDart = int Function(int value, Pointer<Utf8> out, int outLen);

typedef _RankNative = Void Function(
    Pointer<Int32> likes,
    Pointer<Int32> comments,
    Pointer<Int32> saves,
    Pointer<Double> hours,
    Int32 n,
    Pointer<Int32> outOrder);
typedef _RankDart = void Function(
    Pointer<Int32> likes,
    Pointer<Int32> comments,
    Pointer<Int32> saves,
    Pointer<Double> hours,
    int n,
    Pointer<Int32> outOrder);

typedef _ContainsNative = Int32 Function(Pointer<Utf8> haystack, Pointer<Utf8> needle);
typedef _ContainsDart = int Function(Pointer<Utf8> haystack, Pointer<Utf8> needle);

/// Bridge to the C++ core (cpp/swifly_core.cpp, built as libswifly_core.so).
/// Every function falls back to pure Dart if the native library is missing.
class NativeCore {
  NativeCore._();

  static final DynamicLibrary? _library = _openLibrary();

  static DynamicLibrary? _openLibrary() {
    if (!Platform.isAndroid) return null;
    try {
      return DynamicLibrary.open('libswifly_core.so');
    } catch (_) {
      return null;
    }
  }

  /// Runs a lookup with concrete types and returns null if it fails.
  static T? _safe<T>(T Function(DynamicLibrary lib) lookup) {
    final lib = _library;
    if (lib == null) return null;
    try {
      return lookup(lib);
    } catch (_) {
      return null;
    }
  }

  static final _FormatDart? _format = _safe<_FormatDart>(
      (l) => l.lookupFunction<_FormatNative, _FormatDart>('swifly_format_count'));
  static final _RankDart? _rank = _safe<_RankDart>(
      (l) => l.lookupFunction<_RankNative, _RankDart>('swifly_rank'));
  static final _ContainsDart? _contains = _safe<_ContainsDart>(
      (l) => l.lookupFunction<_ContainsNative, _ContainsDart>('swifly_contains_ci'));

  static bool get isNativeReady => _library != null;

  /// 1234 -> "1.2K"
  static String formatCount(int n) {
    final f = _format;
    if (f == null) return _dartFormat(n);
    final buffer = calloc<Uint8>(32).cast<Utf8>();
    try {
      final len = f(n, buffer, 32);
      return buffer.toDartString(length: len);
    } finally {
      calloc.free(buffer);
    }
  }

  /// Case-insensitive contains.
  static bool containsCI(String text, String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    final f = _contains;
    if (f == null) return text.toLowerCase().contains(q.toLowerCase());
    final h = text.toNativeUtf8();
    final n = q.toNativeUtf8();
    try {
      return f(h, n) == 1;
    } finally {
      malloc.free(h);
      malloc.free(n);
    }
  }

  /// Returns post indexes ordered from highest to lowest engagement score.
  static List<int> rankOrder(
    List<int> likes,
    List<int> comments,
    List<int> saves,
    List<double> hours,
  ) {
    final n = likes.length;
    if (n == 0) return const [];
    final f = _rank;
    if (f == null) return _dartRankOrder(likes, comments, saves, hours);

    final pLikes = calloc<Int32>(n);
    final pComments = calloc<Int32>(n);
    final pSaves = calloc<Int32>(n);
    final pHours = calloc<Double>(n);
    final pOrder = calloc<Int32>(n);
    try {
      for (var i = 0; i < n; i++) {
        pLikes[i] = likes[i];
        pComments[i] = comments[i];
        pSaves[i] = saves[i];
        pHours[i] = hours[i];
      }
      f(pLikes, pComments, pSaves, pHours, n, pOrder);
      return List<int>.generate(n, (i) => pOrder[i]);
    } finally {
      calloc.free(pLikes);
      calloc.free(pComments);
      calloc.free(pSaves);
      calloc.free(pHours);
      calloc.free(pOrder);
    }
  }

  // ---- Pure Dart fallbacks (used if the native library is not present) ----

  static String _dartFormat(int n) {
    if (n < 0) n = 0;
    if (n < 1000) return '$n';
    final mega = n >= 1000000;
    final v = mega ? n / 1000000 : n / 1000;
    var s = v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0);
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    return '$s${mega ? 'M' : 'K'}';
  }

  static double _score(int likes, int comments, int saves, double hours) {
    final age = math.max(hours, 0.0);
    return (likes + 2 * comments + 3 * saves + 1).toDouble() /
        math.pow(age + 2.0, 1.5).toDouble();
  }

  static List<int> _dartRankOrder(
    List<int> likes,
    List<int> comments,
    List<int> saves,
    List<double> hours,
  ) {
    final n = likes.length;
    final scores = List<double>.generate(
        n, (i) => _score(likes[i], comments[i], saves[i], hours[i]));
    final order = List<int>.generate(n, (i) => i);
    order.sort((a, b) => scores[b].compareTo(scores[a]));
    return order;
  }
}
