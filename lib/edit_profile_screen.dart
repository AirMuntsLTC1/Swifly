import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'profile_store.dart';
import 'suggest_engine.dart';
import 'suggest_picker.dart';

const Color _brandBlue = Color(0xFF1D6FDC);
const Color _grey = Color(0xFF8E8E8E);

/// Opens a page sliding in from the right with a short fade.
Route<void> _slideRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
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
    if (!ps.isAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allow photo access to change your picture')),
        );
      }
      return;
    }
    if (!mounted) return;
    final result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.image,
        themeColor: _brandBlue,
      ),
    );
    if (result == null || result.isEmpty) return;
    final file = await result.first.file;
    if (file != null) {
      await ProfileStore.instance.setAvatar(file.path);
    }
  }

  Widget _avatarHeader() {
    final path = ProfileStore.instance.avatarPath;
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
                  backgroundImage: path == null ? null : FileImage(File(path)),
                  child: path == null
                      ? const Icon(LucideIcons.user, color: Colors.white, size: 34)
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _brandBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(LucideIcons.image, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile picture',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
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
      onTap: () {
        setState(() {
          if (collapsed) {
            _collapsed.remove(title);
          } else {
            _collapsed.add(title);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
            ),
            AnimatedRotation(
              turns: collapsed ? 0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: const Icon(LucideIcons.chevronDown, color: Colors.black),
            ),
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
              child: Text(
                filled ? displayValue(d, f) : d.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: filled
                    ? const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)
                    : const TextStyle(fontSize: 16, color: _grey),
              ),
            ),
            if (filled) ...[
              Icon(f.audience.icon, size: 16, color: _grey),
              const SizedBox(width: 12),
              const Icon(LucideIcons.pencil, size: 18, color: _grey),
            ],
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
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit profile',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: ProfileStore.instance,
        builder: (context, _) {
          final children = <Widget>[_avatarHeader()];
          for (final section in kProfileSections) {
            final collapsed = _collapsed.contains(section.title);
            children.add(_sectionHeader(section.title, collapsed));
            if (!collapsed) {
              for (final d in section.fields) {
                children.add(_fieldRow(d));
              }
            }
          }
          children.add(const SizedBox(height: 40));
          return ListView(children: children);
        },
      ),
    );
  }
}

/// Edits one field: text, date, or a choice, plus who can see it.
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

  // Search fields: the main pick (company, school, place ...) and, for work and
  // school, an optional second pick (job title, field of study).
  late String _primary;
  late String _secondary;

  String? _error;

  @override
  void initState() {
    super.initState();
    final f = ProfileStore.instance.fieldFor(widget.def.key);
    _text = TextEditingController(text: f.value);
    _choice = f.value;
    _date = DateTime.tryParse(f.value);
    _audience = f.audience;

    if (widget.def.secondary != null) {
      final parts = parseAt(f.value);
      _primary = parts.primary;
      _secondary = parts.secondary;
    } else {
      _primary = f.value;
      _secondary = '';
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _valueToSave {
    final d = widget.def;
    if (d.kind == FieldKind.date) return _date == null ? '' : isoDate(_date!);
    if (d.kind == FieldKind.choice) return _choice;
    if (d.suggest != null) {
      return d.secondary != null ? composeAt(_primary, _secondary) : _primary.trim();
    }
    return normalizeFieldText(d, _text.text);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Tells the suggestion service what was used, so it can be offered first next time.
  void _rememberPicks() {
    final d = widget.def;
    final kind = d.suggest;
    if (kind == null) return;
    final service = SuggestService.instance;
    if (d.multi) {
      for (final v in splitMulti(_primary)) {
        service.remember(kind, v);
      }
    } else if (_primary.trim().isNotEmpty) {
      service.remember(kind, _primary);
    }
    final second = d.secondary;
    if (second != null && _secondary.trim().isNotEmpty) {
      service.remember(second, _secondary);
    }
  }

  void _save() {
    final d = widget.def;

    if (d.suggest != null && d.secondary != null && _primary.trim().isEmpty && _secondary.trim().isNotEmpty) {
      setState(() {
        _error = d.suggest == SuggestKind.company ? 'Add the company first' : 'Add the school first';
      });
      return;
    }

    if (d.suggest == null && (d.kind == FieldKind.text || d.kind == FieldKind.multiline)) {
      final problem = validateFieldText(d, normalizeFieldText(d, _text.text));
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }

    final store = ProfileStore.instance;
    store.setValue(d.key, _valueToSave);
    store.setAudience(d.key, _audience);
    _rememberPicks();
    store.loadFromDatabase(); // Force refresh
    Navigator.pop(context);
  }

  TextInputType _keyboard(FieldValidator v) => switch (v) {
        FieldValidator.email => TextInputType.emailAddress,
        FieldValidator.phone => TextInputType.phone,
        FieldValidator.url => TextInputType.url,
        FieldValidator.handle => TextInputType.text,
        FieldValidator.none => TextInputType.text,
      };

  Widget _smallLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF65676B))),
    );
  }

  Widget _searchInput() {
    final d = widget.def;
    final kind = d.suggest!;
    final second = d.secondary;
    final maxLen = d.multi ? 250 : 80;

    final primary = SuggestPicker(
      key: ValueKey('primary-${d.key}'),
      kind: kind,
      multi: d.multi,
      initialValue: _primary,
      maxLength: maxLen,
      autofocus: _primary.isEmpty,
      errorText: _error,
      onChanged: (v) {
        _primary = v;
        if (_error != null) setState(() => _error = null);
      },
    );
    if (second == null) return primary;

    final isWork = kind == SuggestKind.company;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _smallLabel(isWork ? 'Company' : 'School'),
        primary,
        const SizedBox(height: 24),
        _smallLabel(isWork ? 'Position (optional)' : 'Field of study (optional)'),
        SuggestPicker(
          key: ValueKey('secondary-${d.key}'),
          kind: second,
          initialValue: _secondary,
          onChanged: (v) {
            _secondary = v;
            if (_error != null) setState(() => _error = null);
          },
        ),
      ],
    );
  }

  Widget _input() {
    final d = widget.def;
    if (d.kind == FieldKind.date) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(LucideIcons.cake, color: Colors.black),
        title: Text(
          _date == null ? 'Add your birthday' : isoDate(_date!),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        onTap: _pickDate,
      );
    }
    if (d.kind == FieldKind.choice) {
      return Column(
        children: [
          for (final c in d.choices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c, style: const TextStyle(fontSize: 16)),
              trailing: Icon(
                _choice == c ? LucideIcons.circleCheck : LucideIcons.circle,
                color: Colors.black,
              ),
              onTap: () => setState(() => _choice = c),
            ),
        ],
      );
    }
    if (d.suggest != null) return _searchInput();

    final multi = d.kind == FieldKind.multiline;
    final strict = d.validator != FieldValidator.none;
    return TextField(
      controller: _text,
      cursorColor: Colors.black,
      maxLines: multi ? 4 : 1,
      maxLength: multi ? 150 : 80,
      keyboardType: multi ? TextInputType.multiline : _keyboard(d.validator),
      autocorrect: !strict,
      enableSuggestions: !strict,
      textCapitalization: strict ? TextCapitalization.none : TextCapitalization.sentences,
      onChanged: (v) {
        // Links are checked while typing, so the border turns red right away.
        final live = d.validator == FieldValidator.url
            ? validateFieldText(d, normalizeFieldText(d, v))
            : null;
        if (live != _error) setState(() => _error = live);
      },
      decoration: InputDecoration(
        hintText: d.validator == FieldValidator.url ? 'www.example.com' : d.label,
        errorText: _error,
        errorMaxLines: 2,
        filled: true,
        fillColor: const Color(0xFFF2F2F2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.6),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.def.label,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _input(),
          const SizedBox(height: 28),
          const Text('Who can see this?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 6),
          for (final a in Audience.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(a.icon, color: Colors.black),
              title: Text(a.label, style: const TextStyle(fontSize: 16)),
              trailing: Icon(
                _audience == a ? LucideIcons.circleCheck : LucideIcons.circle,
                color: Colors.black,
              ),
              onTap: () => setState(() => _audience = a),
            ),
          const SizedBox(height: 28),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}



