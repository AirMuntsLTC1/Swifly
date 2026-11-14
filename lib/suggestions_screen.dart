import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'follow_button.dart';
import 'follow_store.dart';
import 'nav_guard.dart';
import 'people_directory.dart';
import 'person_row.dart';
import 'user_profile_screen.dart';

/// Everyone you could follow. People you already follow, and people who follow
/// you (follow back), are never listed here.
class SuggestionsScreen extends StatelessWidget {
  const SuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Suggestions',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([FollowStore.instance, PeopleDirectory.instance]),
        builder: (context, _) {
          final others = FollowStore.instance.suggestedPeople();
          if (others.isEmpty) {
            return const Center(
              child: Text('No new suggestions right now',
                  style: TextStyle(color: Color(0xFF8E8E8E))),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: others.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEAEAEA)),
            itemBuilder: (context, i) {
              final p = others[i];
              return PersonRow(
                person: p,
                onTap: () => pushOnce(context, UserProfileScreen.route(p)),
                trailing: FollowButton(handle: p.handle, compact: true),
              );
            },
          );
        },
      ),
    );
  }
}
