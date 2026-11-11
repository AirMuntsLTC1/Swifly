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

typedef _CountHashtagNative = Int32 Function(Pointer<Utf8> joined, Pointer<Utf8> tag);
typedef _CountHashtagDart = int Function(Pointer<Utf8> joined, Pointer<Utf8> tag);

typedef _ExtractHashtagsNative = Int32 Function(
    Pointer<Utf8> text, Pointer<Utf8> out, Int32 outLen);
typedef _ExtractHashtagsDart = int Function(
    Pointer<Utf8> text, Pointer<Utf8> out, int outLen);

typedef _FollowStatusNative = Int32 Function(Int32 isFollowing, Int32 isFollower);
typedef _FollowStatusDart = int Function(int isFollowing, int isFollower);

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
  static final _CountHashtagDart? _countHashtag = _safe<_CountHashtagDart>(
      (l) => l.lookupFunction<_CountHashtagNative, _CountHashtagDart>(
          'swifly_count_hashtag'));
  static final _ExtractHashtagsDart? _extractHashtags = _safe<_ExtractHashtagsDart>(
      (l) => l.lookupFunction<_ExtractHashtagsNative, _ExtractHashtagsDart>(
          'swifly_extract_hashtags'));
  static final _FollowStatusDart? _followStatus = _safe<_FollowStatusDart>(
      (l) => l.lookupFunction<_FollowStatusNative, _FollowStatusDart>(
          'swifly_get_follow_status'));

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

  /// Counts how many texts in [joinedTexts] (separated by newline) contain [tag].
  static int countHashtag(String joinedTexts, String tag) {
    final f = _countHashtag;
    if (f == null) return _dartCountHashtag(joinedTexts, tag);
    final j = joinedTexts.toNativeUtf8();
    final t = tag.toNativeUtf8();
    try {
      return f(j, t);
    } finally {
      malloc.free(j);
      malloc.free(t);
    }
  }

  /// Extracts all hashtags from [text] as lowercase strings, e.g. "#travel".
  static List<String> extractHashtags(String text) {
    final f = _extractHashtags;
    if (f == null) return _dartExtractHashtags(text);
    final t = text.toNativeUtf8();
    final buffer = calloc<Uint8>(2048).cast<Utf8>();
    try {
      final len = f(t, buffer, 2048);
      if (len <= 0) return const [];
      final s = buffer.toDartString(length: len);
      if (s.isEmpty) return const [];
      return s.split(' ');
    } finally {
      malloc.free(t);
      calloc.free(buffer);
    }
  }

  static int getFollowStatus(bool isFollowing, bool isFollower) {
    final f = _followStatus;
    if (f != null) return f(isFollowing ? 1 : 0, isFollower ? 1 : 0);
    if (isFollowing && isFollower) return 3;
    if (isFollowing) return 1;
    if (isFollower) return 2;
    return 0;
  }

  // ---- Pure Dart fallbacks (used if the native library is not present) ----

  static int _dartCountHashtag(String joinedTexts, String tag) {
    final lowerTag = tag.toLowerCase();
    final needle = lowerTag.startsWith('#') ? lowerTag : '#' + lowerTag;
    var count = 0;
    for (final line in joinedTexts.split('\n')) {
      final lower = line.toLowerCase();
      var pos = 0;
      while (true) {
        final idx = lower.indexOf(needle, pos);
        if (idx < 0) break;
        final leftOk = idx == 0 || !_isWordChar(lower.codeUnitAt(idx - 1));
        final end = idx + needle.length;
        final rightOk = end >= lower.length || !_isWordChar(lower.codeUnitAt(end));
        if (leftOk && rightOk) {
          count++;
          break;
        }
        pos = end;
      }
    }
    return count;
  }

  static bool _isWordChar(int c) =>
      (c >= 48 && c <= 57) ||
      (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      c == 95;

  static List<String> _dartExtractHashtags(String text) {
    final out = <String>[];
    var i = 0;
    while (i < text.length) {
      if (text.codeUnitAt(i) == 35) {
        var j = i + 1;
        while (j < text.length && _isWordChar(text.codeUnitAt(j))) {
          j++;
        }
        if (j > i + 1) {
          out.add(text.substring(i, j).toLowerCase());
        }
        i = j;
      } else {
        i++;
      }
    }
    return out;
  }

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
