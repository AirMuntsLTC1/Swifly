import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'avatar_cache.dart';
import 'local_cache.dart';
import 'location_service.dart';
import 'suggest_engine.dart';

const String _ua = 'SwiflyApp/1.0 (social app)';

/// TheSportsDB's public key "3" is free and needs no sign up. For a higher
/// rate limit, get a personal key at thesportsdb.com and put it here.
const String _sportsDbKey = '3';

/// Kinds whose rows show a picture (artist, team, player, movie, hobby ...).
extension SuggestPictures on SuggestKind {
  bool get hasPicture =>
      this == SuggestKind.music ||
      this == SuggestKind.sport ||
      this == SuggestKind.hobby ||
      this == SuggestKind.tv ||
      this == SuggestKind.movie ||
      this == SuggestKind.game;
}

/// A school found near the phone.
class NearbySchools {
  final String city;
  final List<SuggestEntry> entries;
  const NearbySchools(this.city, this.entries);
}

/// Pictures and places from free public sources. No API key is needed for
/// iTunes, Wikipedia, Wikidata or OpenStreetMap. TheSportsDB uses the public key above.
///
/// Every picture is downloaded once and kept on the phone (AvatarCache). Each
/// name is looked up once, and the answer is remembered on the phone.
class ExternalMedia {
  ExternalMedia._();
  static final ExternalMedia instance = ExternalMedia._();

  final Map<String, Future<String?>> _pictures = {};
  Map<String, String>? _urlMemo;

  Future<dynamic> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.userAgentHeader, _ua);
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return jsonDecode(await res.transform(utf8.decoder).join());
    } finally {
      client.close(force: true);
    }
  }

  /// Local picture file for a name, or null if there is none. Used by the picker rows.
  Future<String?> pictureFor(SuggestKind kind, String title) {
    final key = '${kind.name}|${title.trim().toLowerCase()}';
    return _pictures.putIfAbsent(key, () async {
      final url = await _remoteUrlFor(kind, title.trim());
      if (url == null) return null;
      return AvatarCache.instance.pathFor(url);
    });
  }

  Future<String?> _remoteUrlFor(SuggestKind kind, String title) async {
    final key = '${kind.name}|${title.toLowerCase()}';
    if (_urlMemo == null) {
      final saved = await LocalCache.load('picture_urls');
      _urlMemo = saved is Map
          ? {for (final e in saved.entries) '${e.key}': '${e.value}'}
          : <String, String>{};
    }
    final known = _urlMemo![key];
    if (known != null) return known.isEmpty ? null : known;

    String? url;
    try {
      url = await _lookup(kind, title);
    } catch (_) {
      return null; // network problem: try again next time, do not remember it
    }
    _urlMemo![key] = url ?? '';
    LocalCache.save('picture_urls', _urlMemo!);
    return url;
  }

  Future<String?> _lookup(SuggestKind kind, String title) async {
    switch (kind) {
      case SuggestKind.music:
        return _itunesArtwork(title);
      case SuggestKind.sport:
        return await _sportsPicture('searchteams.php', 't', const ['strTeamBadge', 'strTeamJersey'], title) ??
            await _sportsPicture('searchplayers.php', 'p', const ['strCutout', 'strThumb'], title) ??
            await _wikipediaThumb(title);
      case SuggestKind.hobby:
      case SuggestKind.tv:
      case SuggestKind.movie:
      case SuggestKind.game:
        return _wikipediaThumb(title);
      default:
        return null;
    }
  }

  /// Album artwork of an artist (iTunes Search API, no key).
  Future<String?> _itunesArtwork(String artist) async {
    try {
      final j = await _getJson(Uri.https('itunes.apple.com', '/search',
          {'term': artist, 'entity': 'album', 'limit': '10'}));
      final results = j is Map && j['results'] is List ? j['results'] as List : const [];
      final want = artist.toLowerCase();
      for (final r in results) {
        if (r is! Map) continue;
        final who = '${r['artistName'] ?? ''}'.toLowerCase();
        final art = r['artworkUrl100'];
        if (art is String && art.isNotEmpty && (who.contains(want) || want.contains(who))) {
          return art.replaceFirst('100x100bb', '300x300bb');
        }
      }
    } catch (_) {}
    return null;
  }

  /// Team badge or jersey, or athlete photo, from TheSportsDB (exact name match).
  Future<String?> _sportsPicture(String path, String param, List<String> fields, String name) async {
    try {
      final j = await _getJson(Uri.https('www.thesportsdb.com', '/api/v1/json/$_sportsDbKey/$path', {param: name}));
      final list = j is Map ? (j['teams'] ?? j['player']) : null;
      if (list is List && list.isNotEmpty && list.first is Map) {
        final row = list.first as Map;
        for (final f in fields) {
          final v = row[f];
          if (v is String && v.isNotEmpty) return v;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Thumbnail of a Wikipedia article (free, no key).
  Future<String?> _wikipediaThumb(String title) async {
    try {
      final j = await _getJson(Uri.https(
          'en.wikipedia.org', '/api/rest_v1/page/summary/${title.replaceAll(' ', '_')}'));
      if (j is Map && j['thumbnail'] is Map) {
        final src = (j['thumbnail'] as Map)['source'];
        if (src is String && src.isNotEmpty) return src;
      }
    } catch (_) {}
    return null;
  }

  /// Names that match what the user typed, for the search results of a kind.
  Future<List<SuggestEntry>> searchNames(SuggestKind kind, String query) async {
    final out = <SuggestEntry>[];
    try {
      if (kind == SuggestKind.music) {
        final j = await _getJson(Uri.https('itunes.apple.com', '/search',
            {'term': query, 'entity': 'musicArtist', 'limit': '8'}));
        final results = j is Map && j['results'] is List ? j['results'] as List : const [];
        for (final r in results) {
          if (r is! Map) continue;
          final name = '${r['artistName'] ?? ''}'.trim();
          if (name.isNotEmpty) out.add(SuggestEntry(name, '${r['primaryGenreName'] ?? 'Artist'}', name));
        }
      } else if (kind == SuggestKind.sport) {
        out.addAll(await _sportsSearch(query));
        out.addAll(await _wikiSearch(query, 'Athlete or team'));
      } else {
        out.addAll(await _wikiSearch(query, kind.name));
      }
    } catch (_) {}
    return out;
  }

  Future<List<SuggestEntry>> _wikiSearch(String query, String subtitle) async {
    final j = await _getJson(Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'opensearch',
      'search': query,
      'limit': '8',
      'namespace': '0',
      'format': 'json',
    }));
    if (j is! List || j.length < 2 || j[1] is! List) return const [];
    return [
      for (final t in j[1] as List)
        if (t is String && t.isNotEmpty) SuggestEntry(t, subtitle, t),
    ];
  }

  /// Teams and athletes by exact name, with the team a player plays for as the subtitle.
  Future<List<SuggestEntry>> _sportsSearch(String query) async {
    final out = <SuggestEntry>[];
    try {
      final t = await _getJson(Uri.https('www.thesportsdb.com',
          '/api/v1/json/$_sportsDbKey/searchteams.php', {'t': query}));
      final teams = t is Map && t['teams'] is List ? t['teams'] as List : const [];
      for (final r in teams) {
        if (r is! Map) continue;
        final name = '${r['strTeam'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        final logo = '${r['strTeamBadge'] ?? r['strTeamJersey'] ?? ''}';
        out.add(SuggestEntry(name, 'Team · ${r['strLeague'] ?? ''}', name, logo: logo));
      }
      final p = await _getJson(Uri.https('www.thesportsdb.com',
          '/api/v1/json/$_sportsDbKey/searchplayers.php', {'p': query}));
      final players = p is Map && p['player'] is List ? p['player'] as List : const [];
      for (final r in players) {
        if (r is! Map) continue;
        final name = '${r['strPlayer'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        final logo = '${r['strCutout'] ?? r['strThumb'] ?? ''}';
        out.add(SuggestEntry(name, 'Athlete · ${r['strTeam'] ?? ''}', name, logo: logo));
      }
    } catch (_) {}
    return out;
  }

  /// Schools, colleges and universities within about 15 km of the phone, with
  /// logos from Wikidata. Asks for location permission, and returns null if
  /// there is no permission or no fix.
  Future<NearbySchools?> schoolsNearPhone() async {
    final coords = await LocationService.instance.currentCoords();
    if (coords == null) return null;
    final place = await LocationService.instance.reverseDetailed(coords.lat, coords.lon);
    final city = place?.city ?? '';
    final entries = await _schoolsAround(coords.lat, coords.lon);
    return NearbySchools(city, entries);
  }

  Future<List<SuggestEntry>> _schoolsAround(double lat, double lon) async {
    // Same area: reuse the saved list for 7 days.
    final cacheKey = 'schools_${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
    final saved = await LocalCache.load(cacheKey);
    if (saved is Map && saved['at'] is num) {
      final age = DateTime.now().millisecondsSinceEpoch - (saved['at'] as num).toInt();
      if (age < 7 * 24 * 3600 * 1000 && saved['list'] is List) {
        return [
          for (final e in saved['list'] as List)
            if (e is Map) SuggestEntry('${e['name']}', 'School', '${e['name']}', logo: '${e['logo'] ?? ''}'),
        ];
      }
    }

    final found = await _overpassSchools(lat, lon);
    final logos = await _wikidataLogos([for (final f in found) f.wikidata]);
    final entries = [
      for (final f in found) SuggestEntry(f.name, 'School', f.name, logo: logos[f.wikidata] ?? ''),
    ];
    LocalCache.save(cacheKey, {
      'at': DateTime.now().millisecondsSinceEpoch,
      'list': [for (final e in entries) {'name': e.title, 'logo': e.logo}],
    });
    return entries;
  }

  /// OpenStreetMap school data through Overpass (free, no key).
  Future<List<({String name, String wikidata})>> _overpassSchools(double lat, double lon) async {
    const radius = 15000;
    final query = '[out:json][timeout:25];('
        'node["amenity"~"^(school|college|university)\$"]["name"](around:$radius,$lat,$lon);'
        'way["amenity"~"^(school|college|university)\$"]["name"](around:$radius,$lat,$lon);'
        ');out tags center 120;';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(Uri.parse('https://overpass-api.de/api/interpreter'));
      req.headers.set(HttpHeaders.userAgentHeader, _ua);
      req.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      req.write('data=${Uri.encodeQueryComponent(query)}');
      final res = await req.close().timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return const [];
      final j = jsonDecode(await res.transform(utf8.decoder).join());
      final elements = j is Map && j['elements'] is List ? j['elements'] as List : const [];
      final seen = <String>{};
      final out = <({String name, String wikidata})>[];
      for (final e in elements) {
        if (e is! Map || e['tags'] is! Map) continue;
        final tags = e['tags'] as Map;
        final name = '${tags['name'] ?? ''}'.trim();
        if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
        out.add((name: name, wikidata: '${tags['wikidata'] ?? ''}'));
      }
      return out;
    } finally {
      client.close(force: true);
    }
  }

  /// School logos from Wikidata (property P154 = logo image). Returns wikidata id -> image URL.
  Future<Map<String, String>> _wikidataLogos(List<String> ids) async {
    final out = <String, String>{};
    final valid = ids.where((i) => RegExp(r'^Q\d+$').hasMatch(i)).toSet().toList();
    for (var start = 0; start < valid.length; start += 40) {
      final end = start + 40 > valid.length ? valid.length : start + 40;
      try {
        final j = await _getJson(Uri.https('www.wikidata.org', '/w/api.php', {
          'action': 'wbgetentities',
          'ids': valid.sublist(start, end).join('|'),
          'props': 'claims',
          'format': 'json',
        }));
        final entities = j is Map ? j['entities'] : null;
        if (entities is! Map) continue;
        for (final entry in entities.entries) {
          final file = _logoFileOf(entry.value);
          if (file != null) {
            out['${entry.key}'] =
                'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(file)}?width=160';
          }
        }
      } catch (_) {}
    }
    return out;
  }

  String? _logoFileOf(dynamic entity) {
    if (entity is! Map) return null;
    final claims = entity['claims'];
    if (claims is! Map) return null;
    final p154 = claims['P154'];
    if (p154 is! List || p154.isEmpty || p154.first is! Map) return null;
    final snak = (p154.first as Map)['mainsnak'];
    if (snak is! Map) return null;
    final data = snak['datavalue'];
    if (data is! Map) return null;
    final value = data['value'];
    return value is String && value.isNotEmpty ? value : null;
  }
}

/// A round picture for a suggestion row: the real picture when there is one,
/// otherwise the row's Lucide icon.
class SuggestLogo extends StatefulWidget {
  final SuggestKind kind;
  final String title;

  /// A picture URL the row already knows (for example from a search result).
  final String knownUrl;
  final IconData icon;
  final Color iconColor;
  final Color circle;
  final double size;

  const SuggestLogo({
    super.key,
    required this.kind,
    required this.title,
    this.knownUrl = '',
    required this.icon,
    this.iconColor = Colors.black,
    this.circle = const Color(0xFFF0F2F5),
    this.size = 40,
  });

  @override
  State<SuggestLogo> createState() => _SuggestLogoState();
}

class _SuggestLogoState extends State<SuggestLogo> {
  String? _path;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SuggestLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.knownUrl != widget.knownUrl) _resolve();
  }

  void _resolve() {
    final ticket = ++_ticket;
    if (widget.knownUrl.isNotEmpty) {
      _path = AvatarCache.instance.cachedPath(widget.knownUrl);
    } else {
      _path = null;
    }
    final Future<String?> future = widget.knownUrl.isNotEmpty
        ? AvatarCache.instance.pathFor(widget.knownUrl)
        : ExternalMedia.instance.pictureFor(widget.kind, widget.title);
    future.then((p) {
      if (!mounted || ticket != _ticket || p == null) return;
      setState(() => _path = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _path;
    final fallback = Center(child: Icon(widget.icon, size: 20, color: widget.iconColor));
    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: widget.circle, shape: BoxShape.circle),
      child: p == null
          ? fallback
          : Image.file(
              File(p),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}
