import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import 'location_service.dart';
import 'profile_store.dart';

const Color _brandBlue = Color(0xFF1D6FDC);

/// Remembers the last place you used, so "where I live" is one tap next time.
class StoryPlaceMemory {
  StoryPlaceMemory._();
  static final StoryPlaceMemory instance = StoryPlaceMemory._();

  String zone = '';
  String barangay = '';
  String city = '';
  bool _loaded = false;

  Future<File?> _file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/story_place.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return;
      final j = jsonDecode(await f.readAsString());
      if (j is Map) {
        zone = (j['zone'] ?? '').toString();
        barangay = (j['barangay'] ?? '').toString();
        city = (j['city'] ?? '').toString();
      }
    } catch (_) {}
  }

  Future<void> save(String z, String b, String c) async {
    zone = z;
    barangay = b;
    city = c;
    try {
      final f = await _file();
      await f?.writeAsString(jsonEncode({'zone': z, 'barangay': b, 'city': c}));
    } catch (_) {}
  }
}

/// "Zone 3, Brgy. Poblacion, Davao City"
String composePlaceLabel(String zone, String barangay, String city) {
  final parts = <String>[];
  final z = zone.trim();
  var b = barangay.trim();
  final c = city.trim();
  if (z.isNotEmpty) parts.add(z);
  if (b.isNotEmpty) {
    final low = b.toLowerCase();
    if (!low.startsWith('brgy') && !low.startsWith('barangay') && !low.startsWith('bgy')) {
      b = 'Brgy. $b';
    }
    parts.add(b);
  }
  if (c.isNotEmpty) parts.add(c);
  return parts.join(', ');
}

/// Bottom sheet that returns the place label to put on the story, or null.
Future<String?> showStoryLocationSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _LocationSheet(),
  );
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet();

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final TextEditingController _zone = TextEditingController();
  final TextEditingController _brgy = TextEditingController();
  final TextEditingController _city = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_zone, _brgy, _city]) {
      c.addListener(() => setState(() {}));
    }
    _prefill();
  }

  Future<void> _prefill() async {
    final mem = StoryPlaceMemory.instance;
    await mem.load();
    if (!mounted) return;
    _zone.text = mem.zone;
    _brgy.text = mem.barangay;
    // First time: use the current city from the profile if there is one.
    var city = mem.city;
    if (city.isEmpty) {
      final profileCity = ProfileStore.instance.fieldFor('city').value.trim();
      if (profileCity.isNotEmpty) city = profileCity.split(',').first.trim();
    }
    _city.text = city;
  }

  @override
  void dispose() {
    _zone.dispose();
    _brgy.dispose();
    _city.dispose();
    super.dispose();
  }

  String get _label => composePlaceLabel(_zone.text, _brgy.text, _city.text);

  Future<void> _useGps() async {
    if (_busy) return;
    setState(() => _busy = true);
    final p = await LocationService.instance.useCurrentDetailed(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (p == null) return;
    if (p.zone.isNotEmpty) _zone.text = p.zone;
    if (p.barangay.isNotEmpty) _brgy.text = p.barangay;
    if (p.city.isNotEmpty) _city.text = p.city;
  }

  Future<void> _done() async {
    final label = _label;
    if (label.isEmpty) return;
    await StoryPlaceMemory.instance.save(_zone.text.trim(), _brgy.text.trim(), _city.text.trim());
    if (mounted) Navigator.pop(context, label);
  }

  Widget _field(TextEditingController c, String label, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        textCapitalization: TextCapitalization.words,
        cursorColor: Colors.black,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: Colors.black54),
          filled: true,
          fillColor: const Color(0xFFF2F2F2),
          floatingLabelStyle: const TextStyle(color: Colors.black),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = _label.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D0D0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Add location',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Where you live: zone or block, barangay and city.',
                style: TextStyle(color: Color(0xFF65676B))),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _useGps,
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
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: _brandBlue),
                          )
                        : const Icon(LucideIcons.mapPin, size: 20, color: _brandBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _busy ? 'Finding where you are...' : 'Use my current location',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: _brandBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _field(_zone, 'Zone / Block / Purok', 'e.g. Zone 3 or Block 5', LucideIcons.signpost),
            _field(_brgy, 'Barangay', 'e.g. Poblacion', LucideIcons.house),
            _field(_city, 'City / Municipality', 'e.g. Davao City', LucideIcons.mapPin),
            if (hasLabel)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.mapPin, size: 18, color: _brandBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_label,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: hasLabel ? _done : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFFBDBDBD),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Add to story',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
