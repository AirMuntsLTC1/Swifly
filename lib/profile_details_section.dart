import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'edit_profile_screen.dart';
import 'logo_service.dart';
import 'profile_store.dart';
import 'responsive.dart';
import 'suggest_engine.dart';

const Color _grey = Color(0xFF65676B);
const Color _chipFill = Color(0xFFE8F0FC);
const Color _brandBlue = Color(0xFF1D6FDC);

/// Facebook-style details on your own profile. Work and school show the real
/// logo, places show a pin, and only the fields you filled in appear.
/// Tap any row to change it.
class ProfileDetailsSection extends StatelessWidget {
  const ProfileDetailsSection({super.key});

  static const Set<String> _skip = {'Intro'};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileStore.instance,
      builder: (context, _) {
        final store = ProfileStore.instance;
        final children = <Widget>[];
        for (final section in kProfileSections) {
          if (_skip.contains(section.title)) continue;
          final rows = <Widget>[];
          for (final d in section.fields) {
            final f = store.fieldFor(d.key);
            if (f.value.isEmpty) continue;
            rows.add(d.multi ? _chipsRow(context, d, f) : _row(context, d, f, store));
          }
          if (rows.isEmpty) continue;
          children.add(_heading(context, section.title));
          children.addAll(rows);
        }
        if (children.isEmpty) {
          return _emptyHint(context);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  Widget _emptyHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, editProfileRoute()),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(LucideIcons.mapPin, size: 20, color: Colors.black),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add your city, hometown, work and school',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: _grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
          ),
          IconButton(
            tooltip: 'Edit $title',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.pencil, size: 20, color: Colors.black),
            onPressed: () => Navigator.push(context, editProfileRoute()),
          ),
        ],
      ),
    );
  }

  Widget _leading(BuildContext context, ProfileFieldDef d, ProfileField f) {
    final r = R.of(context);
    final size = r.s(42);
    if (d.suggest == SuggestKind.company) {
      return LogoAvatar(kind: SuggestKind.company, name: parseAt(f.value).primary, size: size);
    }
    if (d.suggest == SuggestKind.school) {
      return LogoAvatar(kind: SuggestKind.school, name: parseAt(f.value).primary, size: size);
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Color(0xFFF0F2F5), shape: BoxShape.circle),
      child: Icon(d.icon, size: r.s(22), color: Colors.black),
    );
  }

  /// The two lines of text for a row: a bold sentence and a small grey label.
  ({String title, String label}) _text(ProfileFieldDef d, ProfileField f, ProfileStore store) {
    switch (d.key) {
      case 'work':
        final p = parseAt(f.value);
        return (
          title: p.secondary.isEmpty ? 'Works at ${p.primary}' : '${p.secondary} at ${p.primary}',
          label: 'Work',
        );
      case 'school':
        final p = parseAt(f.value);
        return (
          title: p.secondary.isEmpty ? 'Studied at ${p.primary}' : 'Studied ${p.secondary} at ${p.primary}',
          label: 'Education',
        );
      case 'city':
        return (title: 'Lives in ${f.value}', label: 'Current city');
      case 'hometown':
        return (title: 'From ${f.value}', label: 'Hometown');
      case 'birthday':
        final age = store.ageYears;
        return (
          title: displayValue(d, f),
          label: age == null ? 'Birthday' : 'Birthday - $age years old',
        );
      default:
        return (title: displayValue(d, f), label: d.label);
    }
  }

  Widget _row(BuildContext context, ProfileFieldDef d, ProfileField f, ProfileStore store) {
    final t = _text(d, f, store);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(context, fieldEditorRoute(d)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _leading(context, d, f),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(t.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: _grey)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: f.audience.label,
              child: Icon(f.audience.icon, size: 16, color: _grey),
            ),
          ],
        ),
      ),
    );
  }

  /// Hobbies, music, languages ... as tappable chips.
  Widget _chipsRow(BuildContext context, ProfileFieldDef d, ProfileField f) {
    final items = splitMulti(f.value);
    if (items.isEmpty) return const SizedBox.shrink();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(context, fieldEditorRoute(d)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(d.icon, size: 18, color: Colors.black),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(d.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _grey)),
                ),
                Icon(f.audience.icon, size: 16, color: _grey),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final it in items)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: R.of(context).width - 56),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _chipFill,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(it,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: _brandBlue)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


