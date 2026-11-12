import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'profile_store.dart';

const Color _grey = Color(0xFF8E8E8E);

/// Personal details and Contact info on your own profile.
/// Each value shows its audience icon: lock for only me, users for followers, globe for everyone.
class ProfileDetailsSection extends StatefulWidget {
  const ProfileDetailsSection({super.key});

  @override
  State<ProfileDetailsSection> createState() => _ProfileDetailsSectionState();
}

class _ProfileDetailsSectionState extends State<ProfileDetailsSection> {
  int _tab = 0; // 0 = Personal details, 1 = Contact info

  Widget _tabButton(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.black : const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Audience audience) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.black),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: _grey)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
              ],
            ),
          ),
          Tooltip(
            message: audience.label,
            child: Icon(audience.icon, size: 16, color: _grey),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows() {
    final store = ProfileStore.instance;
    final rows = <Widget>[];

    if (_tab == 0) {
      final age = store.ageYears;
      if (age != null) {
        rows.add(_row(LucideIcons.cake, 'Age', '$age', store.fieldFor('birthday').audience));
      }
      for (final section in kProfileSections) {
        if (section.title == 'Contact info') continue;
        for (final d in section.fields) {
          final f = store.fieldFor(d.key);
          if (f.value.isEmpty) continue;
          rows.add(_row(d.icon, d.label, displayValue(d, f), f.audience));
        }
      }
    } else {
      final section = kProfileSections.firstWhere((s) => s.title == 'Contact info');
      for (final d in section.fields) {
        final f = store.fieldFor(d.key);
        if (f.value.isEmpty) continue;
        rows.add(_row(d.icon, d.label, f.value, f.audience));
      }
    }

    if (rows.isEmpty) {
      rows.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Nothing here yet. Tap Edit profile to add details.',
            style: TextStyle(color: _grey)),
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _tabButton('Personal details', 0),
            const SizedBox(width: 8),
            _tabButton('Contact info', 1),
          ],
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: ProfileStore.instance,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _rows(),
          ),
        ),
      ],
    );
  }
}
