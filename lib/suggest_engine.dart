import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'database_service.dart';
import 'native_bridge.dart';
import 'suggest_data.dart';

/// What a profile field searches for.
enum SuggestKind {
  company,
  school,
  jobTitle,
  fieldOfStudy,
  hobby,
  music,
  tv,
  movie,
  game,
  sport,
  place,
  language,
}

extension SuggestKindInfo on SuggestKind {
  IconData get icon => switch (this) {
        SuggestKind.company => LucideIcons.briefcase,
        SuggestKind.school => LucideIcons.graduationCap,
        SuggestKind.jobTitle => LucideIcons.briefcase,
        SuggestKind.fieldOfStudy => LucideIcons.graduationCap,
        SuggestKind.hobby => LucideIcons.smile,
        SuggestKind.music => LucideIcons.music,
        SuggestKind.tv => LucideIcons.tv,
        SuggestKind.movie => LucideIcons.video,
        SuggestKind.game => LucideIcons.gamepad2,
        SuggestKind.sport => LucideIcons.shirt,
        SuggestKind.place => LucideIcons.mapPin,
        SuggestKind.language => LucideIcons.languages,
      };

  /// Placeholder shown in the search box.
  String get hint => switch (this) {
        SuggestKind.company => 'Search companies',
        SuggestKind.school => 'Search schools and colleges',
        SuggestKind.jobTitle => 'Search job titles',
        SuggestKind.fieldOfStudy => 'Search fields of study',
        SuggestKind.hobby => 'Search hobbies',
        SuggestKind.music => 'Search artists and genres',
        SuggestKind.tv => 'Search TV shows',
        SuggestKind.movie => 'Search movies',
        SuggestKind.game => 'Search games',
        SuggestKind.sport => 'Search teams and athletes',
        SuggestKind.place => 'Search cities and countries',
        SuggestKind.language => 'Search languages',
      };

  String get raw => switch (this) {
        SuggestKind.company => kCompaniesRaw,
        SuggestKind.school => kSchoolsRaw,
        SuggestKind.jobTitle => kJobTitlesRaw,
        SuggestKind.fieldOfStudy => kFieldsOfStudyRaw,
        SuggestKind.hobby => kHobbiesRaw,
        SuggestKind.music => kMusicRaw,
        SuggestKind.tv => kTvRaw,
        SuggestKind.movie => kMoviesRaw,
        SuggestKind.game => kGamesRaw,
        SuggestKind.sport => kSportsRaw,
        SuggestKind.place => kPlacesRaw,
        SuggestKind.language => kLanguagesRaw,
      };

  /// Typing "nigeria" or "boston" also finds the cities and schools there.
  bool get searchSubtitle => this == SuggestKind.place || this == SuggestKind.school;

  /// "Lagos" is saved as "Lagos, Nigeria".
  bool get valueWithSubtitle => this == SuggestKind.place;
}

/// Separator used when a field holds several values (hobbies, music ...).
const String kMultiSeparator = ' \u2022 ';

List<String> splitMulti(String stored) {
  return stored
      .split(kMultiSeparator)
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String joinMulti(List<String> items) => items.join(kMultiSeparator);

/// "Software Engineer at Google" -> (primary: Google, secondary: Software Engineer).
({String primary, String secondary}) parseAt(String stored) {
  final i = stored.lastIndexOf(' at ');
  if (i <= 0) return (primary: stored, secondary: '');
  return (
    primary: stored.substring(i + 4).trim(),
    secondary: stored.substring(0, i).trim(),
  );
}

String composeAt(String primary, String secondary) {
  final p = primary.trim();
  final s = secondary.trim();
  if (p.isEmpty) return '';
  return s.isEmpty ? p : '$s at $p';
}

const String _accentFrom = '\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5\u00e7\u00e8\u00e9\u00ea\u00eb\u00ec\u00ed\u00ee\u00ef\u00f1\u00f2\u00f3\u00f4\u00f5\u00f6\u00f9\u00fa\u00fb\u00fc\u00fd\u00ff';
const String _accentTo = 'aaaaaaceeeeiiiinooooouuuuyy';

/// Lowercase and remove accents, one character for one character, so positions
/// in the folded text line up with the original (used for the bold highlight).
String foldText(String input) {
  final lower = input.toLowerCase();
  final out = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final ch = lower[i];
    final at = _accentFrom.indexOf(ch);
    if (ch == '\u2019') {
      out.write("'");
    } else {
      out.write(at >= 0 ? _accentTo[at] : ch);
    }
  }
  return out.toString();
}

/// One row in the suggestion list.
class SuggestEntry {
  final String title;
  final String subtitle;

  /// What gets saved on the profile when this row is picked.
  final String value;

  /// True for the "Add what you typed" row.
  final bool custom;

  const SuggestEntry(this.title, this.subtitle, this.value, {this.custom = false});
}

class _Index {
  final List<SuggestEntry> entries;
  final List<String> foldedValues;
  final String joined;
  _Index(this.entries, this.foldedValues, this.joined);

  factory _Index.build(SuggestKind kind) {
    final entries = <SuggestEntry>[];
    final foldedValues = <String>[];
    final haystacks = <String>[];
    final seen = <String>{};

    for (final line in kind.raw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final cut = t.indexOf('|');
      final title = (cut < 0 ? t : t.substring(0, cut)).trim();
      final sub = cut < 0 ? '' : t.substring(cut + 1).trim();
      if (title.isEmpty) continue;

      final isCountry = sub == 'Country';
      final value = kind.valueWithSubtitle && sub.isNotEmpty && !isCountry ? '$title, $sub' : title;
      final key = foldText(value);
      if (!seen.add(key)) continue;

      var hay = foldText(title);
      if (kind.searchSubtitle && sub.isNotEmpty && !isCountry) {
        hay = '$hay, ${foldText(sub)}';
      }
      entries.add(SuggestEntry(title, sub, value));
      foldedValues.add(key);
      haystacks.add(hay.replaceAll('\n', ' '));
    }
    return _Index(entries, foldedValues, haystacks.join('\n'));
  }
}

/// Everything the profile editor needs to suggest values.
///
///  1. The built-in lists in suggest_data.dart, ranked by the C++ core
///     (NativeCore.suggestSearch) so typing "J" shows J-names first.
///  2. Values other people entered, from DatabaseService.searchSuggestions.
///  3. What this person picked recently, shown first when the box is empty.
class SuggestService {
  SuggestService._();
  static final SuggestService instance = SuggestService._();

  final Map<SuggestKind, _Index> _indexes = {};
  final Map<SuggestKind, List<String>> _recent = {};

  _Index _indexFor(SuggestKind kind) => _indexes.putIfAbsent(kind, () => _Index.build(kind));

  /// Instant results from the built-in list. Safe to call on every keystroke.
  List<SuggestEntry> searchLocal(
    SuggestKind kind,
    String query, {
    Set<String> exclude = const {},
    int limit = 6,
  }) {
    final index = _indexFor(kind);
    final skip = exclude.map(foldText).toSet();
    final q = foldText(query).trim();

    if (q.isEmpty) return _initial(kind, index, skip, limit);

    final hits = NativeCore.suggestSearch(
      index.joined,
      q,
      math.min<int>(index.entries.length, limit + skip.length + 12),
    );

    // Loose "letters in order" matches are only worth showing when little else matched.
    final strong = hits.where((h) => h.score >= 400).length;
    final out = <SuggestEntry>[];
    for (final h in hits) {
      if (strong >= 3 && h.score < 300) continue;
      if (skip.contains(index.foldedValues[h.index])) continue;
      out.add(index.entries[h.index]);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Values other people entered that the built-in list does not have.
  Future<List<SuggestEntry>> searchRemote(SuggestKind kind, String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final rows = await DatabaseService.instance
          .searchSuggestions(kind.name, q)
          .timeout(const Duration(seconds: 3));
      return [
        for (final r in rows)
          if ((r['title'] ?? '').trim().isNotEmpty)
            SuggestEntry(r['title']!.trim(), (r['subtitle'] ?? '').trim(), r['title']!.trim()),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Adds database results under the built-in ones without repeats.
  List<SuggestEntry> merge(
    List<SuggestEntry> local,
    List<SuggestEntry> remote, {
    Set<String> exclude = const {},
    int limit = 6,
  }) {
    final seen = <String>{...exclude.map(foldText), ...local.map((e) => foldText(e.value))};
    final out = [...local];
    for (final r in remote) {
      if (out.length >= limit) break;
      if (seen.add(foldText(r.value))) out.add(r);
    }
    return out;
  }

  /// True if [value] is already in the list (so no "Add ..." row is needed).
  bool hasExact(SuggestKind kind, String value, List<SuggestEntry> shown) {
    final key = foldText(value).trim();
    if (key.isEmpty) return true;
    for (final e in shown) {
      if (foldText(e.value) == key || foldText(e.title) == key) return true;
    }
    return _indexFor(kind).foldedValues.contains(key);
  }

  /// Remember a value this person used, and tell the database (it feeds
  /// the shared suggestions other people see).
  void remember(SuggestKind kind, String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    final list = _recent.putIfAbsent(kind, () => <String>[]);
    final key = foldText(v);
    list.removeWhere((e) => foldText(e) == key);
    list.insert(0, v);
    if (list.length > 6) list.removeLast();
    DatabaseService.instance.recordSuggestionPick(kind.name, v).catchError((_) {});
  }

  List<SuggestEntry> _initial(SuggestKind kind, _Index index, Set<String> skip, int limit) {
    final out = <SuggestEntry>[];
    final used = <String>{};
    for (final v in _recent[kind] ?? const <String>[]) {
      final key = foldText(v);
      if (skip.contains(key) || !used.add(key)) continue;
      final at = index.foldedValues.indexOf(key);
      out.add(at >= 0 ? index.entries[at] : SuggestEntry(v, '', v));
      if (out.length >= limit) return out;
    }
    for (var i = 0; i < index.entries.length && out.length < limit; i++) {
      final key = index.foldedValues[i];
      if (skip.contains(key) || !used.add(key)) continue;
      out.add(index.entries[i]);
    }
    return out;
  }

  /// Whether the empty box is showing the person's recent picks.
  bool hasRecent(SuggestKind kind) => (_recent[kind] ?? const <String>[]).isNotEmpty;
}
