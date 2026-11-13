import os
import zipfile
import shutil

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True) if os.path.dirname(path) else None
    with open(path, 'w') as f:
        f.write(content)
    print(f"✅ Updated: {path}")

print("Applying Ultimate Swifly Architecture & UI Fixes...\n")

# 1. EDIT PROFILE: Top Right Save Button with Indicator
edit_profile = """import 'dart:io';

import 'package:flutter/material.dart';
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
                  backgroundImage: hasImage ? (path.startsWith('http') ? NetworkImage(path) : FileImage(File(path)) as ImageProvider) : null,
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
"""
write_file("lib/edit_profile_screen.dart", edit_profile)

# 2. FIX SHARE SHEET KEYBOARD OVERFLOW
share_sheet_fix = """import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dm_theme.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'post_model.dart';
import 'people_directory.dart';

const Color _blue = Color(0xFF1D6FDC);
const Color _grey = Color(0xFF8E8E8E);

PostRef postRefFor(Post p) {
  String? thumb;
  var video = false;
  if (p.media.isNotEmpty) {
    thumb = p.media.first.previewPath;
    video = p.media.first.isVideo;
  }
  return PostRef(postId: p.id, authorName: p.authorName, authorHandle: p.authorHandle, title: p.text.trim(), thumbPath: thumb, isVideo: video, mediaCount: p.media.length);
}

Future<void> showSharePostDialog(BuildContext context, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  final sent = await showGeneralDialog<int>(
    context: context, barrierDismissible: true, barrierLabel: 'Close', barrierColor: Colors.black.withValues(alpha: 0.45), transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => _ShareDialog(post: post),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1).animate(curved), child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved), child: child)));
    },
  );
  if (sent != null && sent > 0) {
    messenger..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(sent == 1 ? 'Post sent to 1 person' : 'Post sent to $sent people'), behavior: SnackBarBehavior.floating));
  }
}

class _ShareDialog extends StatefulWidget {
  final Post post;
  const _ShareDialog({required this.post});
  @override State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final Set<String> _selected = <String>{};
  final TextEditingController _note = TextEditingController();
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override void dispose() { _note.dispose(); _search.dispose(); super.dispose(); }

  List<String> _people() {
    final all = FollowStore.instance.followingHandles.where((h) => h != kMeHandle).toList()..sort((a, b) {
      final ma = FollowStore.instance.isFollower(a) ? 0 : 1; final mb = FollowStore.instance.isFollower(b) ? 0 : 1;
      if (ma != mb) return ma.compareTo(mb); return dmName(a).toLowerCase().compareTo(dmName(b).toLowerCase());
    });
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [for (final h in all) if (dmName(h).toLowerCase().contains(q) || h.toLowerCase().contains(q)) h];
  }

  void _send() {
    if (_selected.isEmpty) return;
    final ref = postRefFor(widget.post);
    final note = _note.text.trim();
    for (final h in _selected) { ChatStore.instance.send(h, note, post: ref); }
    PostStore.instance.registerShare(widget.post.id, _selected.length);
    Navigator.pop(context, _selected.length);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = (mq.size.width / 390).clamp(0.85, 1.15).toDouble();
    final p = widget.post;
    final caption = p.text.trim().isEmpty ? 'Photo or video post' : p.text.trim();
    
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom), // KEYBOARD FIX
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: mq.viewInsets.bottom > 0 ? 8 : 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440, maxHeight: mq.size.height * 0.78),
              child: Material(
                color: Colors.white, borderRadius: BorderRadius.circular(24), clipBehavior: Clip.antiAlias, elevation: 12,
                child: ListenableBuilder(
                  listenable: FollowStore.instance,
                  builder: (context, _) {
                    final people = _people();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                          child: Row(children: [
                            const Icon(LucideIcons.send, size: 20, color: Colors.black),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Share post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black))),
                            IconButton(icon: const Icon(LucideIcons.x, color: Colors.black), onPressed: () => Navigator.pop(context)),
                          ]),
                        ),
                        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Text('${p.authorName}: $caption', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: _grey))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _search, cursorColor: Colors.black, onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(hintText: 'Search people you follow', hintStyle: const TextStyle(color: _grey), prefixIcon: const Icon(LucideIcons.search, size: 18, color: _grey), isDense: true, filled: true, fillColor: const Color(0xFFF2F2F2), contentPadding: const EdgeInsets.symmetric(vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: people.isEmpty
                              ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Follow people to share posts with them', textAlign: TextAlign.center, style: TextStyle(color: _grey))))
                              : GridView.builder(
                                  shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 96 * s, mainAxisSpacing: 8, crossAxisSpacing: 4, mainAxisExtent: 62 * s + 8 + 4 + 18),
                                  itemCount: people.length,
                                  itemBuilder: (_, i) {
                                    final h = people[i]; final on = _selected.contains(h); final size = 62 * s;
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque, onTap: () => setState(() => on ? _selected.remove(h) : _selected.add(h)),
                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                        SizedBox(width: size + 8, height: size + 8, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                                          AnimatedScale(scale: on ? 0.9 : 1, duration: const Duration(milliseconds: 160), child: AnimatedContainer(duration: const Duration(milliseconds: 160), padding: const EdgeInsets.all(2.5), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? _blue : Colors.transparent, width: 2.5)), child: DmAvatar(handle: h, size: size - 8, gap: Colors.white))),
                                          Positioned(right: 0, bottom: 2, child: AnimatedScale(scale: on ? 1 : 0, duration: const Duration(milliseconds: 220), curve: Curves.elasticOut, child: Container(width: 22, height: 22, decoration: BoxDecoration(color: _blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(LucideIcons.check, size: 13, color: Colors.white)))),
                                        ])),
                                        const SizedBox(height: 4),
                                        Text(dmName(h), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Colors.black, fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
                                      ]),
                                    );
                                  },
                                ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEAEAEA)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                          child: Row(children: [
                            Expanded(child: TextField(controller: _note, maxLength: 150, cursorColor: Colors.black, decoration: InputDecoration(hintText: 'Add a message...', hintStyle: const TextStyle(color: _grey), counterText: '', isDense: true, filled: true, fillColor: const Color(0xFFF2F2F2), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
                            const SizedBox(width: 10),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200), height: 44,
                              decoration: BoxDecoration(color: _selected.isEmpty ? const Color(0xFFBDBDBD) : _blue, borderRadius: BorderRadius.circular(22)),
                              child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(22), onTap: _selected.isEmpty ? null : _send, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.send, size: 17, color: Colors.white), const SizedBox(width: 8), Text(_selected.isEmpty ? 'Send' : 'Send (${_selected.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))])))),
                            ),
                          ]),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
"""
write_file("lib/share_sheet.dart", share_sheet_fix)

# 3. STARTUP SPLASH SCREEN WITH INDICATOR & INIT
splash_screen = """import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'auth/auth_flow.dart';
import 'app_bootstrap.dart';
import 'auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  String _status = 'Connecting to Swifly...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await AuthService.init().timeout(const Duration(seconds: 10));
      if (!AuthService.instance.needsLogin) {
        AuthService.instance.applyUser();
        setState(() => _status = 'Loading your feed...');
        await loadAppData();
      }
    } catch (e) {
      debugPrint('Init Error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, animation, secondaryAnimation) => startScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 112, height: 112,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 10))]),
                child: const Icon(LucideIcons.flaskConical, color: Colors.white, size: 56),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Swifly', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.black)),
            const SizedBox(height: 6),
            Text('Connect. Share. Inspire.', style: TextStyle(fontSize: 14, color: Colors.black.withValues(alpha: 0.5))),
            const SizedBox(height: 48),
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black)),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
          ],
        ),
      ),
    );
  }
}
"""
write_file("lib/splash_screen.dart", splash_screen)

# 4. MAIN.DART (Remove blocking load)
main_dart = """import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'app_feedback.dart';
import 'media/media_pipeline.dart';
import 'logo_service.dart';
import 'notification_banner.dart';
import 'notification_router.dart';
import 'profile_store.dart';
import 'realtime_router.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 120);
  
  ProfileStore.instance.loadFromDevice();
  LogoService.instance.load();
  RealtimeRouter.init();
  NotificationBanner.init();
  
  runApp(const SocialApp());
  
  MediaPipeline.instance.ensureReady().then((_) => MediaPipeline.instance.trimCache());
}

class SocialApp extends StatelessWidget {
  const SocialApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifly', navigatorKey: appNavigatorKey, scaffoldMessengerKey: appMessengerKey, debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery.withClampedTextScaling(minScaleFactor: 0.9, maxScaleFactor: 1.05, child: DefaultTextStyle.merge(style: const TextStyle(fontFamily: kAppFont), child: child!)),
      theme: ThemeData(
        useMaterial3: true, fontFamily: kAppFont, textTheme: _appTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black, brightness: Brightness.light),
        scaffoldBackgroundColor: Colors.white,
        snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF262626), elevation: 6, insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 28), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.35), actionTextColor: const Color(0xFF8AB4FF)),
      ),
      home: const SplashScreen(),
    );
  }
}

const String kAppFont = 'Roboto';
TextTheme _appTextTheme() {
  return ThemeData.light().textTheme.apply(bodyColor: Colors.black, displayColor: Colors.black).copyWith(titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black), titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black), bodyMedium: const TextStyle(fontSize: 15, color: Colors.black), bodySmall: const TextStyle(fontSize: 13, color: Color(0xFF65676B))).apply(fontFamily: kAppFont);
}
"""
write_file("lib/main.dart", main_dart)

# 5. PAGINATION: DatabaseService
db_service = open("lib/database_service.dart").read()
db_service = db_service.replace(
    "Future<List<Map<String, dynamic>>> fetchPosts() async {\n    final me = _requireMe();",
    "Future<List<Map<String, dynamic>>> fetchPosts({int limit = 4, int offset = 0}) async {\n    final me = _requireMe();"
)
db_service = db_service.replace(
    ".order('created_at', ascending: false)\n        .limit(100);",
    ".order('created_at', ascending: false)\n        .range(offset, offset + limit - 1);"
)
write_file("lib/database_service.dart", db_service)

# 6. PAGINATION: PostStore & Typing Indicator Store
post_model = open("lib/post_model.dart").read()
post_model = post_model.replace(
    "bool _isLoadingMore = false;\n  bool get isLoadingMore => _isLoadingMore;", # Just in case
    ""
)
# Add to PostStore class
post_model = post_model.replace(
    "class PostStore extends ChangeNotifier {\n  PostStore._();\n  static final PostStore instance = PostStore._();\n  final List<Post> _posts = [];\n  int _nextId = 1;",
    "class PostStore extends ChangeNotifier {\n  PostStore._();\n  static final PostStore instance = PostStore._();\n  final List<Post> _posts = [];\n  int _nextId = 1;\n  bool _isLoadingMore = false;\n  bool get isLoadingMore => _isLoadingMore;\n\n  Future<void> loadMorePosts() async {\n    if (_isLoadingMore) return;\n    _isLoadingMore = true;\n    notifyListeners();\n    try {\n      final saved = await DatabaseService.instance.fetchPosts(limit: 4, offset: _posts.length);\n      if (saved.isNotEmpty) {\n        for (final r in saved) { _posts.add(postFromRow(r)); }\n        notifyListeners();\n      }\n    } catch (e) {\n      // ignore\n    }\n    _isLoadingMore = false;\n    notifyListeners();\n  }"
)
write_file("lib/post_model.dart", post_model)

# 7. FEED WIDGETS: Infinite Scroll
feed_widgets = open("lib/feed_widgets.dart").read()
feed_widgets = feed_widgets.replace(
    "class FeedTab extends StatelessWidget {\n  const FeedTab({super.key});\n\n  @override\n  Widget build(BuildContext context) {\n    return RefreshIndicator(",
    "class FeedTab extends StatefulWidget {\n  const FeedTab({super.key});\n  @override\n  State<FeedTab> createState() => _FeedTabState();\n}\n\nclass _FeedTabState extends State<FeedTab> {\n  final ScrollController _scrollController = ScrollController();\n\n  @override\n  void initState() {\n    super.initState();\n    _scrollController.addListener(() {\n      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {\n        PostStore.instance.loadMorePosts();\n      }\n    });\n  }\n\n  @override\n  void dispose() {\n    _scrollController.dispose();\n    super.dispose();\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    return RefreshIndicator("
)
feed_widgets = feed_widgets.replace(
    "return ListView.builder(\n            physics: const AlwaysScrollableScrollPhysics(),\n            padding: const EdgeInsets.only(bottom: 96),\n            itemCount: posts.length,\n            itemBuilder: (context, i) => PostCard(key: ValueKey(posts[i].id), post: posts[i]),\n          );",
    "return ListView.builder(\n            controller: _scrollController,\n            physics: const AlwaysScrollableScrollPhysics(),\n            padding: const EdgeInsets.only(bottom: 96),\n            itemCount: posts.length + (PostStore.instance.isLoadingMore ? 1 : 0),\n            itemBuilder: (context, i) {\n              if (i == posts.length) {\n                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)));\n              }\n              return PostCard(key: ValueKey(posts[i].id), post: posts[i]);\n            },\n          );"
)
write_file("lib/feed_widgets.dart", feed_widgets)

# 8. TYPING INDICATOR in Chat
inbox_store = open("lib/inbox_store.dart").read()
# Add a simple typing store
inbox_store += """

class ChatTypingStore extends ChangeNotifier {
  ChatTypingStore._();
  static final ChatTypingStore instance = ChatTypingStore._();
  final Set<String> _typingHandles = {};

  bool isTyping(String handle) => _typingHandles.contains(handle);

  void setTyping(String handle, bool typing) {
    if (typing) {
      if (_typingHandles.add(handle)) notifyListeners();
    } else {
      if (_typingHandles.remove(handle)) notifyListeners();
    }
  }
}
"""
write_file("lib/inbox_store.dart", inbox_store)

chat_screen = open("lib/chat_screen.dart").read()
chat_screen = chat_screen.replace(
    "final msgs = store.thread(_handle).reversed.toList();",
    "final msgs = store.thread(_handle).reversed.toList();\n        final isTyping = ChatTypingStore.instance.isTyping(_handle);"
)
chat_screen = chat_screen.replace(
    "isRequest ? _requestBar(c) : _composer(c),",
    "isRequest ? _requestBar(c) : _composer(c),\n              if (isTyping) Padding(padding: const EdgeInsets.all(8.0), child: Text('typing...', style: TextStyle(color: c.sub, fontStyle: FontStyle.italic))),"
)
write_file("lib/chat_screen.dart", chat_screen)

print("\n✅ All code fixes applied successfully!")

# 9. CREATE THE FINAL ZIP
print("📦 Creating Swifly_final.zip...")
zip_path = "/storage/emulated/0/Download/Swifly_final.zip"
if os.path.exists(zip_path):
    os.remove(zip_path)

with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk("."):
        if any(ignored in root for ignored in ['.git', 'build', '.dart_tool', 'node_modules']):
            continue
        for file in files:
            zf.write(os.path.join(root, file))

print(f"\n🎉 SUCCESS! Your final project is zipped at:\n{zip_path}")
