import 'dart:io';

import 'package:flutter/material.dart';
import 'avatar_cache.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'profile_store.dart';
import 'suggest_engine.dart';
import 'suggest_picker.dart';

const Color _brandBlue = Color(0xFF1D6FDC);
const Color _grey = Color(0xFF8E8E8E);

Route<void> _slideRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved), child: FadeTransition(opacity: curved, child: child));
    },
  );
}

Route<void> editProfileRoute() => _slideRoute(const EditProfileScreen());
Route<void> fieldEditorRoute(ProfileFieldDef def) => _slideRoute(FieldEditorScreen(def: def));

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final Set<String> _collapsed = {};

  Future<void> _pickAvatar() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return;
    if (!mounted) return;
    final result = await AssetPicker.pickAssets(context, pickerConfig: AssetPickerConfig(maxAssets: 1, requestType: RequestType.image, themeColor: _brandBlue));
    if (result == null || result.isEmpty) return;
    final file = await result.first.file;
    if (file != null) await ProfileStore.instance.setAvatar(file.path);
  }

  Widget _avatarHeader() {
    final path = ProfileStore.instance.avatarPath;
    final hasImage = path != null && path.isNotEmpty;
    return InkWell(
      onTap: _pickAvatar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.black,
                  backgroundImage: hasImage ? avatarImageProvider(path) : null,
                  child: !hasImage ? const Icon(LucideIcons.user, color: Colors.white, size: 34) : null,
                ),
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: _brandBlue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(LucideIcons.image, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile picture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                SizedBox(height: 2),
                Text('Tap to choose a photo', style: TextStyle(fontSize: 14, color: _grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool collapsed) {
    return InkWell(
      onTap: () => setState(() { if (collapsed) { _collapsed.remove(title); } else { _collapsed.add(title); } }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black))),
            AnimatedRotation(turns: collapsed ? 0 : 0.5, duration: const Duration(milliseconds: 200), child: const Icon(LucideIcons.chevronDown, color: Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(ProfileFieldDef d) {
    final f = ProfileStore.instance.fieldFor(d.key);
    final filled = f.value.isNotEmpty;
    return InkWell(
      onTap: () => Navigator.push(context, fieldEditorRoute(d)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(d.icon, size: 22, color: Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Text(filled ? displayValue(d, f) : d.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: filled ? const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black) : const TextStyle(fontSize: 16, color: _grey)),
            ),
            if (filled) ...[Icon(f.audience.icon, size: 16, color: _grey), const SizedBox(width: 12), const Icon(LucideIcons.pencil, size: 18, color: _grey)],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: ProfileStore.instance,
        builder: (context, _) {
          final children = <Widget>[_avatarHeader()];
          for (final section in kProfileSections) {
            final collapsed = _collapsed.contains(section.title);
            children.add(_sectionHeader(section.title, collapsed));
            if (!collapsed) { for (final d in section.fields) { children.add(_fieldRow(d)); } }
          }
          children.add(const SizedBox(height: 40));
          return ListView(children: children);
        },
      ),
    );
  }
}

class FieldEditorScreen extends StatefulWidget {
  final ProfileFieldDef def;
  const FieldEditorScreen({super.key, required this.def});
  @override
  State<FieldEditorScreen> createState() => _FieldEditorScreenState();
}

class _FieldEditorScreenState extends State<FieldEditorScreen> {
  late final TextEditingController _text;
  late String _choice;
  late DateTime? _date;
  late Audience _audience;
  late String _primary, _secondary;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final f = ProfileStore.instance.fieldFor(widget.def.key);
    _text = TextEditingController(text: f.value);
    _choice = f.value;
    _date = DateTime.tryParse(f.value);
    _audience = f.audience;
    if (widget.def.secondary != null) { final parts = parseAt(f.value); _primary = parts.primary; _secondary = parts.secondary; } else { _primary = f.value; _secondary = ''; }
  }

  @override
  void dispose() { _text.dispose(); super.dispose(); }

  String get _valueToSave {
    final d = widget.def;
    if (d.kind == FieldKind.date) return _date == null ? '' : isoDate(_date!);
    if (d.kind == FieldKind.choice) return _choice;
    if (d.suggest != null) return d.secondary != null ? composeAt(_primary, _secondary) : _primary.trim();
    return normalizeFieldText(d, _text.text);
  }

  Future<void> _save() async {
    final d = widget.def;
    if (d.suggest != null && d.secondary != null && _primary.trim().isEmpty && _secondary.trim().isNotEmpty) {
      setState(() => _error = d.suggest == SuggestKind.company ? 'Add the company first' : 'Add the school first'); return;
    }
    if (d.suggest == null && (d.kind == FieldKind.text || d.kind == FieldKind.multiline)) {
      final problem = validateFieldText(d, normalizeFieldText(d, _text.text));
      if (problem != null) { setState(() => _error = problem); return; }
    }

    setState(() => _isSaving = true);
    final store = ProfileStore.instance;
    store.setValue(d.key, _valueToSave);
    store.setAudience(d.key, _audience);
    
    // Simulate network delay for the saving indicator
    await Future.delayed(const Duration(milliseconds: 600));
    
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  Widget _input() {
    final d = widget.def;
    if (d.kind == FieldKind.date) {
      return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(LucideIcons.cake, color: Colors.black), title: Text(_date == null ? 'Add your birthday' : isoDate(_date!), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: _date ?? DateTime(2000, 1, 1), firstDate: DateTime(1900), lastDate: DateTime.now());
        if (picked != null) setState(() => _date = picked);
      });
    }
    if (d.kind == FieldKind.choice) {
      return Column(children: [ for (final c in d.choices) ListTile(contentPadding: EdgeInsets.zero, title: Text(c, style: const TextStyle(fontSize: 16)), trailing: Icon(_choice == c ? LucideIcons.circleCheck : LucideIcons.circle, color: Colors.black), onTap: () => setState(() => _choice = c)) ]);
    }
    if (d.suggest != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.secondary != null) const Text('Company / School', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF65676B))),
          SuggestPicker(key: ValueKey('primary-${d.key}'), kind: d.suggest!, multi: d.multi, initialValue: _primary, maxLength: d.multi ? 250 : 80, autofocus: _primary.isEmpty, errorText: _error, onChanged: (v) { _primary = v; if (_error != null) setState(() => _error = null); }),
          if (d.secondary != null) ...[
            const SizedBox(height: 24),
            Text(d.suggest == SuggestKind.company ? 'Position (optional)' : 'Field of study (optional)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF65676B))),
            SuggestPicker(key: ValueKey('secondary-${d.key}'), kind: d.secondary!, initialValue: _secondary, onChanged: (v) { _secondary = v; if (_error != null) setState(() => _error = null); }),
          ],
        ],
      );
    }
    final multi = d.kind == FieldKind.multiline;
    return TextField(
      controller: _text, cursorColor: Colors.black, maxLines: multi ? 4 : 1, maxLength: multi ? 150 : 80,
      decoration: InputDecoration(hintText: d.label, errorText: _error, filled: true, fillColor: const Color(0xFFF2F2F2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(LucideIcons.x, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Text(widget.def.label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isSaving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: _brandBlue))
                : ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _input(),
          const SizedBox(height: 28),
          const Text('Who can see this?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 6),
          for (final a in Audience.values) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(a.icon, color: Colors.black), title: Text(a.label, style: const TextStyle(fontSize: 16)), trailing: Icon(_audience == a ? LucideIcons.circleCheck : LucideIcons.circle, color: Colors.black), onTap: () => setState(() => _audience = a)),
        ],
      ),
    );
  }
}
