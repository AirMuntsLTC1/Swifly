import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'edit_profile_screen.dart';
import 'native_bridge.dart';
import 'profile_store.dart';

const Color _grey = Color(0xFF65676B);

/// Facebook-style details on your own profile: a heading with a pencil, then
/// only the fields you have filled in. A section with nothing filled in is hidden.
class ProfileDetailsSection extends StatelessWidget {
  const ProfileDetailsSection({super.key});

  static const Set<String> _personalSkip = {'Contact info', 'Intro'};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileStore.instance,
      builder: (context, _) {
        final personal = <ProfileFieldDef>[];
        final contact = <ProfileFieldDef>[];
        for (final section in kProfileSections) {
          if (section.title == 'Contact info') {
            contact.addAll(section.fields);
          } else if (!_personalSkip.contains(section.title)) {
            personal.addAll(section.fields);
          }
        }

        final children = <Widget>[
          ..._section(context, 'Personal details', personal),
          ..._section(context, 'Contact info', contact),
        ];
        if (children.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  /// Heading and filled rows. Returns nothing if no field in the section is filled.
  List<Widget> _section(BuildContext context, String title, List<ProfileFieldDef> defs) {
    final store = ProfileStore.instance;
    final rows = <Widget>[];
    for (final d in defs) {
      final f = store.fieldFor(d.key);
      if (f.value.isEmpty) continue;
      rows.add(_row(d, f, store));
    }
    if (rows.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
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
      ),
      ...rows,
    ];
  }

  Widget _row(ProfileFieldDef d, ProfileField f, ProfileStore store) {
    final isBirthday = d.key == 'birthday';
    final age = isBirthday ? store.ageYears : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(d.icon, size: 22, color: Colors.black),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayValue(d, f),
                    style: const TextStyle(fontSize: 16, color: Colors.black)),
                if (age != null)
                  Text('$age years old',
                      style: const TextStyle(fontSize: 13, color: _grey)),
              ],
            ),
          ),
          Tooltip(
            message: f.audience.label,
            child: Icon(f.audience.icon, size: 16, color: _grey),
          ),
        ],
      ),
    );
  }
}
