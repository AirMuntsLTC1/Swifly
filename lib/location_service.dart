import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A real place: "Lagos, Lagos State, Nigeria".
class PlaceResult {
  final String name; // the short name, e.g. "Lagos"
  final String full; // what gets saved, e.g. "Lagos, Nigeria"
  final String detail; // longer line shown under it
  final String countryCode; // "NG"
  final double? lat;
  final double? lon;

  const PlaceResult({
    required this.name,
    required this.full,
    required this.detail,
    this.countryCode = '',
    this.lat,
    this.lon,
  });
}

enum LocationOutcome { ok, serviceOff, denied, deniedForever, failed }

class LocationFix {
  final LocationOutcome outcome;
  final PlaceResult? place;
  const LocationFix(this.outcome, [this.place]);
}

/// Real device location (the system permission popup) and real place search
/// (OpenStreetMap Nominatim, free, no key needed).
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const String _userAgent = 'SwiflyApp/1.0 (social app)';

  final Map<String, List<PlaceResult>> _searchCache = {};

  // ---------- device location ----------

  /// Asks Android for permission (showing the real "Allow location" popup),
  /// reads the GPS position and turns it into a city name.
  Future<LocationFix> currentPlace() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return const LocationFix(LocationOutcome.serviceOff);

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return const LocationFix(LocationOutcome.denied);
      }
      if (perm == LocationPermission.deniedForever) {
        return const LocationFix(LocationOutcome.deniedForever);
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        ).timeout(const Duration(seconds: 15));
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return const LocationFix(LocationOutcome.failed);

      final place = await reverse(pos.latitude, pos.longitude);
      if (place == null) return const LocationFix(LocationOutcome.failed);
      return LocationFix(LocationOutcome.ok, place);
    } catch (_) {
      return const LocationFix(LocationOutcome.failed);
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Shows a clear message for each outcome. Returns the place if it worked.
  Future<PlaceResult?> useCurrentLocation(BuildContext context) async {
    final fix = await currentPlace();
    if (!context.mounted) return fix.place;
    switch (fix.outcome) {
      case LocationOutcome.ok:
        return fix.place;
      case LocationOutcome.serviceOff:
        _snack(context, 'Turn on location (GPS) to use your current city',
            action: 'Settings', onAction: openLocationSettings);
      case LocationOutcome.denied:
        _snack(context, 'Location permission was not allowed');
      case LocationOutcome.deniedForever:
        _snack(context, 'Location is blocked. Allow it in app settings',
            action: 'Settings', onAction: openAppSettings);
      case LocationOutcome.failed:
        _snack(context, 'Could not find your location. Check your internet and try again');
    }
    return null;
  }

  void _snack(BuildContext context, String text, {String? action, VoidCallback? onAction}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
      ));
  }

  // ---------- Nominatim ----------

  Future<dynamic> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set('Accept-Language', 'en');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  /// Coordinates -> a city name.
  Future<PlaceResult?> reverse(double lat, double lon) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lon',
        'zoom': '10',
        'addressdetails': '1',
      });
      final json = await _getJson(uri);
      if (json is! Map) return null;
      return _fromRow(json, lat: lat, lon: lon);
    } catch (_) {
      return null;
    }
  }

  /// Type "lag" and get real cities and towns from around the world.
  Future<List<PlaceResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final key = q.toLowerCase();
    final hit = _searchCache[key];
    if (hit != null) return hit;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'q': q,
        'limit': '8',
        'addressdetails': '1',
        'featuretype': 'settlement',
      });
      final json = await _getJson(uri);
      if (json is! List) return const [];
      final out = <PlaceResult>[];
      final seen = <String>{};
      for (final row in json) {
        if (row is! Map) continue;
        final p = _fromRow(row);
        if (p == null) continue;
        if (seen.add(p.full.toLowerCase())) out.add(p);
      }
      _searchCache[key] = out;
      return out;
    } catch (_) {
      return const [];
    }
  }

  PlaceResult? _fromRow(Map row, {double? lat, double? lon}) {
    final addr = row['address'];
    if (addr is! Map) {
      final dn = (row['display_name'] ?? '').toString();
      if (dn.isEmpty) return null;
      final first = dn.split(',').first.trim();
      return PlaceResult(name: first, full: dn, detail: dn);
    }
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = addr[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final city = pick(['city', 'town', 'village', 'municipality', 'suburb', 'county', 'state_district']);
    final state = pick(['state', 'region', 'province']);
    final country = pick(['country']);
    final cc = (addr['country_code'] ?? '').toString().toUpperCase();
    final name = city.isNotEmpty ? city : (row['name'] ?? state).toString();
    if (name.isEmpty) return null;

    final parts = <String>[name];
    if (state.isNotEmpty && state != name) parts.add(state);
    if (country.isNotEmpty) parts.add(country);
    final detail = parts.join(', ');
    final full = country.isNotEmpty && country != name ? '$name, $country' : name;

    double? la = lat;
    double? lo = lon;
    la ??= double.tryParse('${row['lat'] ?? ''}');
    lo ??= double.tryParse('${row['lon'] ?? ''}');
    return PlaceResult(
      name: name,
      full: full,
      detail: detail,
      countryCode: cc,
      lat: la,
      lon: lo,
    );
  }
}

/// Country flag emoji from a two-letter code ("NG" -> flag). Empty if unknown.
String flagEmoji(String code) {
  if (code.length != 2) return '';
  final a = code.toUpperCase().codeUnits;
  if (a.any((c) => c < 65 || c > 90)) return '';
  return String.fromCharCodes([0x1F1E6 + a[0] - 65, 0x1F1E6 + a[1] - 65]);
}

/// "Use my current location" button used under the city and hometown boxes.
class UseLocationButton extends StatefulWidget {
  final ValueChanged<PlaceResult> onPlace;
  const UseLocationButton({super.key, required this.onPlace});

  @override
  State<UseLocationButton> createState() => _UseLocationButtonState();
}

class _UseLocationButtonState extends State<UseLocationButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    final place = await LocationService.instance.useCurrentLocation(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (place != null) widget.onPlace(place);
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1D6FDC);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _tap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: blue),
                  )
                : const Icon(LucideIcons.mapPin, size: 20, color: blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _busy ? 'Finding your location...' : 'Use my current location',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
