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

typedef _AgeNative = Int32 Function(Int32 by, Int32 bm, Int32 bd, Int32 ty, Int32 tm, Int32 td);
typedef _AgeDart = int Function(int by, int bm, int bd, int ty, int tm, int td);

typedef _CanSeeNative = Int32 Function(Int32 audience, Int32 isOwner, Int32 viewerFollowsOwner);
typedef _CanSeeDart = int Function(int audience, int isOwner, int viewerFollowsOwner);

typedef _SuggestNative = Int32 Function(Pointer<Utf8> joined, Pointer<Utf8> query,
    Int32 maxResults, Pointer<Int32> outIdx, Pointer<Int32> outScores);
typedef _SuggestDart = int Function(Pointer<Utf8> joined, Pointer<Utf8> query,
    int maxResults, Pointer<Int32> outIdx, Pointer<Int32> outScores);


typedef _DmBucketNative = Int32 Function(Int32 isFollowing, Int32 iReplied, Int32 accepted, Int32 hours, Int32 unread);
typedef _DmBucketDart = int Function(int isFollowing, int iReplied, int accepted, int hours, int unread);
typedef _DmFilterNative = Int32 Function(Int32 flags, Int32 mask);
typedef _DmFilterDart = int Function(int flags, int mask);
typedef _DmSortNative = Void Function(Pointer<Int64> lastMs, Int32 n, Pointer<Int32> out);
typedef _DmSortDart = void Function(Pointer<Int64> lastMs, int n, Pointer<Int32> out);
typedef _DmTimeNative = Int32 Function(Int64 seconds, Pointer<Utf8> out, Int32 outLen);
typedef _DmTimeDart = int Function(int seconds, Pointer<Utf8> out, int outLen);
typedef _DmClipNative = Int32 Function(Pointer<Utf8> text, Int32 maxChars, Pointer<Utf8> out, Int32 outLen);
typedef _DmClipDart = int Function(Pointer<Utf8> text, int maxChars, Pointer<Utf8> out, int outLen);
typedef _DmRankNative = Void Function(Pointer<Int32> followsMe, Pointer<Int32> mutual, Int32 n, Pointer<Int32> out);
typedef _DmRankDart = void Function(Pointer<Int32> followsMe, Pointer<Int32> mutual, int n, Pointer<Int32> out);

/// One search hit: the position in the candidate list and how well it matched.
class SuggestHit {
  final int index;
  final int score;
  const SuggestHit(this.index, this.score);
}

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

  static final _AgeDart? _ageYears = _safe<_AgeDart>(
      (l) => l.lookupFunction<_AgeNative, _AgeDart>('swifly_age_years'));
  static final _CanSeeDart? _canSeeFn = _safe<_CanSeeDart>(
      (l) => l.lookupFunction<_CanSeeNative, _CanSeeDart>('swifly_can_see'));

  static final _SuggestDart? _suggest = _safe<_SuggestDart>(
      (l) => l.lookupFunction<_SuggestNative, _SuggestDart>('swifly_suggest_search'));


  static final _DmBucketDart? _dmBucketFn = _safe<_DmBucketDart>(
      (l) => l.lookupFunction<_DmBucketNative, _DmBucketDart>('swifly_dm_bucket'));
  static final _DmFilterDart? _dmFilterFn = _safe<_DmFilterDart>(
      (l) => l.lookupFunction<_DmFilterNative, _DmFilterDart>('swifly_dm_filter_pass'));
  static final _DmSortDart? _dmSortFn = _safe<_DmSortDart>(
      (l) => l.lookupFunction<_DmSortNative, _DmSortDart>('swifly_dm_sort_threads'));
  static final _DmTimeDart? _dmTimeFn = _safe<_DmTimeDart>(
      (l) => l.lookupFunction<_DmTimeNative, _DmTimeDart>('swifly_dm_time_label'));
  static final _DmClipDart? _dmClipFn = _safe<_DmClipDart>(
      (l) => l.lookupFunction<_DmClipNative, _DmClipDart>('swifly_dm_clip'));
  static final _DmRankDart? _dmRankFn = _safe<_DmRankDart>(
      (l) => l.lookupFunction<_DmRankNative, _DmRankDart>('swifly_dm_rank_people'));

  static bool get isNativeReady => _library != null;

  /// Whole years between a birth date and a date. Returns -1 if the dates are invalid.
  static int ageYears(int by, int bm, int bd, int ty, int tm, int td) {
    final f = _ageYears;
    if (f != null) return f(by, bm, bd, ty, tm, td);
    if (by <= 0 || bm < 1 || bm > 12 || bd < 1 || bd > 31) return -1;
    if (ty < by) return -1;
    if (ty == by && (tm < bm || (tm == bm && td < bd))) return -1;
    var age = ty - by;
    if (tm < bm || (tm == bm && td < bd)) age -= 1;
    return age;
  }

  /// Privacy rule. audience: 0 = only me, 1 = followers, 2 = everyone.
  static bool canSee(int audience, {required bool isOwner, required bool viewerFollowsOwner}) {
    final f = _canSeeFn;
    if (f != null) return f(audience, isOwner ? 1 : 0, viewerFollowsOwner ? 1 : 0) == 1;
    if (isOwner) return true;
    if (audience == 0) return false;
    if (audience == 1) return viewerFollowsOwner;
    return true;
  }

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

  /// Search-as-you-type ranking for profile suggestions.
  /// [joined] holds every candidate (lowercase, accent-free) separated by '\n'.
  /// [query] must be lowercase and accent-free too. Best match first.
  static List<SuggestHit> suggestSearch(String joined, String query, int maxResults) {
    if (query.isEmpty || maxResults <= 0 || joined.isEmpty) return const [];
    final f = _suggest;
    if (f == null) return _dartSuggest(joined, query, maxResults);

    final j = joined.toNativeUtf8();
    final q = query.toNativeUtf8();
    final idx = calloc<Int32>(maxResults);
    final scores = calloc<Int32>(maxResults);
    try {
      final n = f(j, q, maxResults, idx, scores);
      return List<SuggestHit>.generate(n, (i) => SuggestHit(idx[i], scores[i]));
    } finally {
      malloc.free(j);
      malloc.free(q);
      calloc.free(idx);
      calloc.free(scores);
    }
  }


  // ---- Direct messages ----

  /// 0 = Primary, 1 = Requests, 2 = General.
  static int dmBucket({
    required bool isFollowing,
    required bool iReplied,
    required bool accepted,
    required int hoursSinceLast,
    required int unread,
  }) {
    final f = _dmBucketFn;
    if (f != null) {
      return f(isFollowing ? 1 : 0, iReplied ? 1 : 0, accepted ? 1 : 0, hoursSinceLast, unread);
    }
    if (!isFollowing && !iReplied && !accepted) return 1;
    if (unread == 0 && hoursSinceLast >= 24 * 7) return 2;
    return 0;
  }

  /// Filter flags: 1 unread, 2 unanswered, 4 story replies, 8 following, 16 follows me.
  static bool dmFilterPass(int flags, int mask) {
    final f = _dmFilterFn;
    if (f != null) return f(flags, mask) == 1;
    return (flags & mask) == mask;
  }

  /// Conversation positions ordered newest first.
  static List<int> dmSortThreads(List<int> lastMs) {
    final n = lastMs.length;
    if (n == 0) return const [];
    final f = _dmSortFn;
    if (f == null) {
      final order = List<int>.generate(n, (i) => i);
      order.sort((a, b) {
        final c = lastMs[b].compareTo(lastMs[a]);
        return c != 0 ? c : a.compareTo(b);
      });
      return order;
    }
    final p = calloc<Int64>(n);
    final o = calloc<Int32>(n);
    try {
      for (var i = 0; i < n; i++) {
        p[i] = lastMs[i];
      }
      f(p, n, o);
      return List<int>.generate(n, (i) => o[i]);
    } finally {
      calloc.free(p);
      calloc.free(o);
    }
  }

  /// "now", "5m", "3h", "2d", "3w".
  static String dmTimeLabel(DateTime t) {
    final seconds = DateTime.now().difference(t).inSeconds;
    final f = _dmTimeFn;
    if (f == null) return _dartDmTime(seconds);
    final buffer = calloc<Uint8>(24).cast<Utf8>();
    try {
      final len = f(seconds, buffer, 24);
      return buffer.toDartString(length: len);
    } finally {
      calloc.free(buffer);
    }
  }

  /// Cuts [text] to [maxChars] characters and adds "..." (used for previews and quotes).
  static String dmClip(String text, int maxChars) {
    final f = _dmClipFn;
    if (f == null) return _dartDmClip(text, maxChars);
    final t = text.toNativeUtf8();
    final size = maxChars * 4 + 8;
    final buffer = calloc<Uint8>(size).cast<Utf8>();
    try {
      final len = f(t, maxChars, buffer, size);
      return buffer.toDartString(length: len);
    } finally {
      malloc.free(t);
      calloc.free(buffer);
    }
  }

  /// People who follow me first, then by mutual count. Returns positions.
  static List<int> dmRankPeople(List<bool> followsMe, List<int> mutual) {
    final n = followsMe.length;
    if (n == 0) return const [];
    final f = _dmRankFn;
    int score(int i) => (followsMe[i] ? 1000 : 0) + (mutual[i] > 99 ? 99 : mutual[i]);
    if (f == null) {
      final order = List<int>.generate(n, (i) => i);
      order.sort((a, b) {
        final c = score(b).compareTo(score(a));
        return c != 0 ? c : a.compareTo(b);
      });
      return order;
    }
    final a = calloc<Int32>(n);
    final m = calloc<Int32>(n);
    final o = calloc<Int32>(n);
    try {
      for (var i = 0; i < n; i++) {
        a[i] = followsMe[i] ? 1 : 0;
        m[i] = mutual[i];
      }
      f(a, m, n, o);
      return List<int>.generate(n, (i) => o[i]);
    } finally {
      calloc.free(a);
      calloc.free(m);
      calloc.free(o);
    }
  }

  static String _dartDmTime(int s) {
    if (s < 60) return 'now';
    if (s < 3600) return '${s ~/ 60}m';
    if (s < 86400) return '${s ~/ 3600}h';
    if (s < 86400 * 7) return '${s ~/ 86400}d';
    return '${s ~/ (86400 * 7)}w';
  }

  static String _dartDmClip(String text, int maxChars) {
    if (maxChars <= 0) return '';
    final flat = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
    final runes = flat.runes.toList();
    if (runes.length <= maxChars) return flat;
    return '${String.fromCharCodes(runes.take(maxChars))}...';
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

  // ---- Suggestion scoring fallback (mirrors swifly_suggest_search in C++) ----

  static bool _isBreak(int c) =>
      c == 32 || c == 45 || c == 46 || c == 47 || c == 38 || c == 40 || c == 44 || c == 58 || c == 43;

  static bool _hasWordPrefix(String c, String w) {
    if (w.isEmpty) return true;
    var pos = c.indexOf(w);
    while (pos >= 0) {
      if (pos == 0 || _isBreak(c.codeUnitAt(pos - 1))) return true;
      pos = c.indexOf(w, pos + 1);
    }
    return false;
  }

  static bool _oneTypoPrefix(String c, String q) {
    final n = q.length;
    if (n < 4 || c.length < n) return false;
    var diff = 0;
    var first = 0;
    for (var i = 0; i < n; i++) {
      if (c.codeUnitAt(i) != q.codeUnitAt(i)) {
        if (diff == 0) first = i;
        diff++;
        if (diff > 2) return false;
      }
    }
    if (diff == 1) return true;
    return diff == 2 &&
        first + 1 < n &&
        c.codeUnitAt(first) == q.codeUnitAt(first + 1) &&
        c.codeUnitAt(first + 1) == q.codeUnitAt(first);
  }

  static bool _isSubsequence(String c, String q) {
    var qi = 0;
    for (var ci = 0; ci < c.length && qi < q.length; ci++) {
      if (c.codeUnitAt(ci) == q.codeUnitAt(qi)) qi++;
    }
    return qi == q.length;
  }

  static int _suggestScore(String c, String q, List<String> words) {
    if (c == q) return 1000;
    final int extra = c.length - math.min<int>(c.length, q.length);
    if (c.length > q.length && c.startsWith(q)) return 900 - math.min<int>(extra, 60);
    var pos = c.indexOf(q);
    final first = pos;
    while (pos >= 0) {
      if (pos > 0 && _isBreak(c.codeUnitAt(pos - 1))) return 700 - math.min<int>(pos, 60);
      pos = c.indexOf(q, pos + 1);
    }
    if (first >= 0) return 500 - math.min<int>(first, 60);
    if (words.length >= 2 && words.every((w) => _hasWordPrefix(c, w))) return 450;
    if (_oneTypoPrefix(c, q)) return 320 - math.min<int>(extra, 40);
    if (q.length >= 3 && _isSubsequence(c, q)) return 150;
    return 0;
  }

  static List<SuggestHit> _dartSuggest(String joined, String q, int maxResults) {
    final words = q.split(' ').where((w) => w.isNotEmpty).toList();
    final lines = joined.split('\n');
    final hits = <SuggestHit>[];
    for (var i = 0; i < lines.length; i++) {
      final score = _suggestScore(lines[i], q, words);
      if (score > 0) hits.add(SuggestHit(i, score));
    }
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
    return hits.length > maxResults ? hits.sublist(0, maxResults) : hits;
  }
}
