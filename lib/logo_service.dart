import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'suggest_engine.dart';

/// Website of well-known companies and schools, so their real logo shows
/// instantly (and offline once it has been loaded once). Anything not listed
/// here is looked up on Wikidata the first time it is used.
const Map<String, String> kKnownDomains = {
  // companies
  'google': 'google.com',
  'microsoft': 'microsoft.com',
  'apple': 'apple.com',
  'amazon': 'amazon.com',
  'meta': 'meta.com',
  'tesla': 'tesla.com',
  'netflix': 'netflix.com',
  'samsung electronics': 'samsung.com',
  'intel': 'intel.com',
  'ibm': 'ibm.com',
  'oracle': 'oracle.com',
  'adobe': 'adobe.com',
  'salesforce': 'salesforce.com',
  'nvidia': 'nvidia.com',
  'amd': 'amd.com',
  'spotify': 'spotify.com',
  'uber': 'uber.com',
  'airbnb': 'airbnb.com',
  'twitter': 'x.com',
  'x corp': 'x.com',
  'linkedin': 'linkedin.com',
  'tiktok': 'tiktok.com',
  'bytedance': 'bytedance.com',
  'snapchat': 'snapchat.com',
  'pinterest': 'pinterest.com',
  'reddit': 'reddit.com',
  'discord': 'discord.com',
  'telegram': 'telegram.org',
  'whatsapp': 'whatsapp.com',
  'zoom': 'zoom.us',
  'slack': 'slack.com',
  'dropbox': 'dropbox.com',
  'shopify': 'shopify.com',
  'paypal': 'paypal.com',
  'stripe': 'stripe.com',
  'square': 'squareup.com',
  'visa': 'visa.com',
  'mastercard': 'mastercard.com',
  'flutterwave': 'flutterwave.com',
  'paystack': 'paystack.com',
  'opay': 'opay.com',
  'moniepoint': 'moniepoint.com',
  'kuda bank': 'kuda.com',
  'safaricom': 'safaricom.co.ke',
  'mtn group': 'mtn.com',
  'airtel': 'airtel.in',
  'vodafone': 'vodafone.com',
  'github': 'github.com',
  'gitlab': 'gitlab.com',
  'openai': 'openai.com',
  'anthropic': 'anthropic.com',
  'walmart': 'walmart.com',
  'target': 'target.com',
  'costco': 'costco.com',
  'nike': 'nike.com',
  'adidas': 'adidas.com',
  'coca-cola': 'coca-cola.com',
  'pepsico': 'pepsico.com',
  'mcdonalds': 'mcdonalds.com',
  "mcdonald's": 'mcdonalds.com',
  'starbucks': 'starbucks.com',
  'disney': 'disney.com',
  'the walt disney company': 'disney.com',
  'toyota': 'toyota.com',
  'honda': 'honda.com',
  'bmw': 'bmw.com',
  'mercedes-benz': 'mercedes-benz.com',
  'volkswagen': 'vw.com',
  'ford': 'ford.com',
  'general motors': 'gm.com',
  'boeing': 'boeing.com',
  'airbus': 'airbus.com',
  'shell': 'shell.com',
  'bp': 'bp.com',
  'exxonmobil': 'exxonmobil.com',
  'chevron': 'chevron.com',
  'jpmorgan chase': 'jpmorganchase.com',
  'goldman sachs': 'goldmansachs.com',
  'morgan stanley': 'morganstanley.com',
  'bank of america': 'bankofamerica.com',
  'citigroup': 'citigroup.com',
  'wells fargo': 'wellsfargo.com',
  'hsbc': 'hsbc.com',
  'barclays': 'barclays.com',
  'standard chartered': 'sc.com',
  'access bank': 'accessbankplc.com',
  'gtbank': 'gtbank.com',
  'guaranty trust bank': 'gtbank.com',
  'zenith bank': 'zenithbank.com',
  'first bank of nigeria': 'firstbanknigeria.com',
  'uba': 'ubagroup.com',
  'united bank for africa': 'ubagroup.com',
  'dangote group': 'dangote.com',
  'dangote': 'dangote.com',
  'deloitte': 'deloitte.com',
  'pwc': 'pwc.com',
  'kpmg': 'kpmg.com',
  'ey': 'ey.com',
  'mckinsey & company': 'mckinsey.com',
  'accenture': 'accenture.com',
  'cisco': 'cisco.com',
  'dell': 'dell.com',
  'hp': 'hp.com',
  'sony': 'sony.com',
  'lg': 'lg.com',
  'huawei': 'huawei.com',
  'xiaomi': 'mi.com',
  'alibaba': 'alibaba.com',
  'tencent': 'tencent.com',
  'baidu': 'baidu.com',
  'spacex': 'spacex.com',
  'nasa': 'nasa.gov',
  'bbc': 'bbc.com',
  'cnn': 'cnn.com',
  'youtube': 'youtube.com',
  'instagram': 'instagram.com',
  'facebook': 'facebook.com',
  'canva': 'canva.com',
  'figma': 'figma.com',
  'notion': 'notion.so',
  'atlassian': 'atlassian.com',
  'twilio': 'twilio.com',
  'cloudflare': 'cloudflare.com',
  'jumia': 'jumia.com',
  'andela': 'andela.com',
  // schools
  'harvard university': 'harvard.edu',
  'stanford university': 'stanford.edu',
  'massachusetts institute of technology': 'mit.edu',
  'yale university': 'yale.edu',
  'princeton university': 'princeton.edu',
  'columbia university': 'columbia.edu',
  'university of pennsylvania': 'upenn.edu',
  'cornell university': 'cornell.edu',
  'duke university': 'duke.edu',
  'northwestern university': 'northwestern.edu',
  'brown university': 'brown.edu',
  'dartmouth college': 'dartmouth.edu',
  'california institute of technology': 'caltech.edu',
  'johns hopkins university': 'jhu.edu',
  'university of chicago': 'uchicago.edu',
  'new york university': 'nyu.edu',
  'carnegie mellon university': 'cmu.edu',
  'georgia institute of technology': 'gatech.edu',
  'university of california, berkeley': 'berkeley.edu',
  'university of california, los angeles': 'ucla.edu',
  'university of michigan': 'umich.edu',
  'university of texas at austin': 'utexas.edu',
  'university of washington': 'washington.edu',
  'university of florida': 'ufl.edu',
  'ohio state university': 'osu.edu',
  'arizona state university': 'asu.edu',
  'boston university': 'bu.edu',
  'purdue university': 'purdue.edu',
  'howard university': 'howard.edu',
  'morehouse college': 'morehouse.edu',
  'university of oxford': 'ox.ac.uk',
  'university of cambridge': 'cam.ac.uk',
  'imperial college london': 'imperial.ac.uk',
  'university college london': 'ucl.ac.uk',
  'london school of economics': 'lse.ac.uk',
  "king's college london": 'kcl.ac.uk',
  'university of edinburgh': 'ed.ac.uk',
  'university of manchester': 'manchester.ac.uk',
  'university of toronto': 'utoronto.ca',
  'mcgill university': 'mcgill.ca',
  'university of british columbia': 'ubc.ca',
  'university of lagos': 'unilag.edu.ng',
  'university of ibadan': 'ui.edu.ng',
  'university of nigeria, nsukka': 'unn.edu.ng',
  'university of nigeria': 'unn.edu.ng',
  'obafemi awolowo university': 'oauife.edu.ng',
  'ahmadu bello university': 'abu.edu.ng',
  'university of benin': 'uniben.edu',
  'covenant university': 'covenantuniversity.edu.ng',
  'lagos state university': 'lasu.edu.ng',
  'federal university of technology, akure': 'futa.edu.ng',
  'university of ilorin': 'unilorin.edu.ng',
  'university of port harcourt': 'uniport.edu.ng',
  'university of cape town': 'uct.ac.za',
  'university of the witwatersrand': 'wits.ac.za',
  'stellenbosch university': 'sun.ac.za',
  'university of nairobi': 'uonbi.ac.ke',
  'university of ghana': 'ug.edu.gh',
  'makerere university': 'mak.ac.ug',
  'american university in cairo': 'aucegypt.edu',
  'national university of singapore': 'nus.edu.sg',
  'tsinghua university': 'tsinghua.edu.cn',
  'peking university': 'pku.edu.cn',
  'university of tokyo': 'u-tokyo.ac.jp',
  'eth zurich': 'ethz.ch',
  'university of melbourne': 'unimelb.edu.au',
  'university of sydney': 'sydney.edu.au',
  'australian national university': 'anu.edu.au',
};

/// Real logo for a company or school, with a safe fallback (coloured initials).
class LogoService {
  LogoService._();
  static final LogoService instance = LogoService._();

  static const String _ua = 'SwiflyApp/1.0 (social app)';

  /// key -> logo url ('' means "looked up, nothing found")
  final Map<String, String> _cache = {};
  final Map<String, Future<String>> _pending = {};
  bool _loaded = false;
  File? _file;
  Timer? _saveTimer;

  String _key(SuggestKind kind, String name) =>
      '${kind == SuggestKind.school ? 's' : 'c'}|${foldText(name).trim()}';

  static String faviconUrl(String domain) =>
      'https://www.google.com/s2/favicons?domain=$domain&sz=128';

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/logo_cache.json');
      if (await _file!.exists()) {
        final data = jsonDecode(await _file!.readAsString());
        if (data is Map) {
          data.forEach((k, v) {
            if (k is String && v is String) _cache[k] = v;
          });
        }
      }
    } catch (_) {}
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () async {
      try {
        await _file?.writeAsString(jsonEncode(_cache));
      } catch (_) {}
    });
  }

  /// Instant answer if we already know it, otherwise null.
  String? cached(SuggestKind kind, String name) {
    final k = _key(kind, name);
    final c = _cache[k];
    if (c != null) return c.isEmpty ? null : c;
    final d = kKnownDomains[foldText(name).trim()];
    return d == null ? null : faviconUrl(d);
  }

  /// Finds the logo address, asking Wikidata if needed. Never throws.
  Future<String?> resolve(SuggestKind kind, String name) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    final quick = cached(kind, n);
    if (quick != null) return quick;
    final k = _key(kind, n);
    if (_cache[k] == '') return null;
    final url = await (_pending[k] ??= _lookup(kind, n, k));
    _pending.remove(k);
    return url.isEmpty ? null : url;
  }

  /// Remember a logo that came with a search result.
  void remember(SuggestKind kind, String name, String url) {
    if (url.isEmpty) return;
    _cache[_key(kind, name)] = url;
    _scheduleSave();
  }

  Future<dynamic> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, _ua);
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return jsonDecode(await res.transform(utf8.decoder).join());
    } finally {
      client.close(force: true);
    }
  }

  static final RegExp _schoolWords = RegExp(
      r'university|college|school|institute|academy|polytechnic|seminary|campus',
      caseSensitive: false);
  static final RegExp _orgWords = RegExp(
      r'company|corporation|bank|brand|manufacturer|retailer|telecom|firm|enterprise|business|group|service|platform|software|airline|agency|organization|organisation|startup|studio|network|conglomerate|multinational|provider|maker|fintech|website|app',
      caseSensitive: false);

  Future<String> _lookup(SuggestKind kind, String name, String key) async {
    try {
      final found = await _wikidata(kind, name);
      final url = found?.logo ?? '';
      _cache[key] = url;
      _scheduleSave();
      return url;
    } catch (_) {
      return '';
    }
  }

  Future<({String logo, String domain})?> _best(
      SuggestKind kind, List<Map> hits) async {
    if (hits.isEmpty) return null;
    final ids = hits.map((h) => h['id']).whereType<String>().take(6).toList();
    final json = await _getJson(Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbgetentities',
      'ids': ids.join('|'),
      'props': 'claims',
      'format': 'json',
    }));
    final entities = json is Map ? json['entities'] : null;
    if (entities is! Map) return null;

    ({String logo, String domain})? firstAny;
    for (final h in hits.take(6)) {
      final id = h['id'];
      final desc = (h['description'] ?? '').toString();
      final e = entities[id];
      if (e is! Map) continue;
      final claims = e['claims'];
      if (claims is! Map) continue;

      String? site;
      final p856 = claims['P856'];
      if (p856 is List && p856.isNotEmpty) {
        final v = p856.first['mainsnak']?['datavalue']?['value'];
        if (v is String) site = v;
      }
      String? logoFile;
      final p154 = claims['P154'];
      if (p154 is List && p154.isNotEmpty) {
        final v = p154.first['mainsnak']?['datavalue']?['value'];
        if (v is String) logoFile = v;
      }
      String domain = '';
      if (site != null) {
        final uri = Uri.tryParse(site);
        domain = (uri?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
      }
      String logo = '';
      if (domain.isNotEmpty) {
        logo = faviconUrl(domain);
      } else if (logoFile != null) {
        logo =
            'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(logoFile)}?width=128';
      }
      if (logo.isEmpty) continue;
      final item = (logo: logo, domain: domain);
      firstAny ??= item;
      final matches = kind == SuggestKind.school
          ? _schoolWords.hasMatch(desc)
          : _orgWords.hasMatch(desc) && !_schoolWords.hasMatch(desc);
      if (matches) return item;
    }
    return firstAny;
  }

  Future<({String logo, String domain})?> _wikidata(SuggestKind kind, String name) async {
    final json = await _getJson(Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbsearchentities',
      'search': name,
      'language': 'en',
      'type': 'item',
      'limit': '6',
      'format': 'json',
    }));
    final list = json is Map ? json['search'] : null;
    if (list is! List) return null;
    return _best(kind, [for (final x in list) if (x is Map) x]);
  }

  /// Live search of real companies or schools worldwide (Wikidata).
  Future<List<SuggestEntry>> searchOrgs(SuggestKind kind, String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final json = await _getJson(Uri.https('www.wikidata.org', '/w/api.php', {
        'action': 'wbsearchentities',
        'search': q,
        'language': 'en',
        'type': 'item',
        'limit': '8',
        'format': 'json',
      }));
      final list = json is Map ? json['search'] : null;
      if (list is! List) return const [];
      final out = <SuggestEntry>[];
      for (final x in list) {
        if (x is! Map) continue;
        final label = (x['label'] ?? '').toString().trim();
        final desc = (x['description'] ?? '').toString().trim();
        if (label.isEmpty) continue;
        final isSchool = _schoolWords.hasMatch(desc);
        if (kind == SuggestKind.school && !isSchool) continue;
        if (kind == SuggestKind.company && (isSchool || !_orgWords.hasMatch(desc))) continue;
        out.add(SuggestEntry(label, desc, label, logo: cached(kind, label) ?? ''));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

/// Round logo of a company or school. Shows the real logo; while it loads, or
/// if none exists, shows the first letters on a colour that is the same every time.
class LogoAvatar extends StatefulWidget {
  final SuggestKind kind;
  final String name;
  final double size;
  final String? knownUrl;
  final bool square;

  const LogoAvatar({
    super.key,
    required this.kind,
    required this.name,
    this.size = 40,
    this.knownUrl,
    this.square = false,
  });

  @override
  State<LogoAvatar> createState() => _LogoAvatarState();
}

class _LogoAvatarState extends State<LogoAvatar> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _url = (widget.knownUrl != null && widget.knownUrl!.isNotEmpty)
        ? widget.knownUrl
        : LogoService.instance.cached(widget.kind, widget.name);
    _resolve();
  }

  @override
  void didUpdateWidget(covariant LogoAvatar old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name || old.kind != widget.kind) {
      _url = (widget.knownUrl != null && widget.knownUrl!.isNotEmpty)
          ? widget.knownUrl
          : LogoService.instance.cached(widget.kind, widget.name);
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (_url != null) return;
    final name = widget.name;
    await LogoService.instance.load();
    final found = await LogoService.instance.resolve(widget.kind, name);
    if (!mounted || widget.name != name) return;
    if (found != null) setState(() => _url = found);
  }

  static const List<Color> _palette = [
    Color(0xFF1D6FDC), Color(0xFF0F9D58), Color(0xFFE8710A), Color(0xFF8E24AA),
    Color(0xFFD93025), Color(0xFF00897B), Color(0xFF5D4037), Color(0xFF3949AB),
  ];

  String get _initials {
    final words = widget.name
        .split(RegExp(r'[\s,.&\-]+'))
        .where((w) => w.isNotEmpty && w.toLowerCase() != 'of' && w.toLowerCase() != 'the')
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Widget _fallback() {
    final color = _palette[widget.name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: widget.size * 0.36,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final radius = widget.square ? BorderRadius.circular(size * 0.22) : BorderRadius.circular(size);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E6EB)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: _url == null
            ? _fallback()
            : Padding(
                padding: EdgeInsets.all(size * 0.1),
                child: Image.network(
                  _url!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => _fallback(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _fallback(),
                ),
              ),
      ),
    );
  }
}


