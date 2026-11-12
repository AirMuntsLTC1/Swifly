import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'follow_button.dart';
import 'tag_friends_screen.dart';
import 'user_profile_screen.dart';

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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kPeople.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFFEAEAEA)),
        itemBuilder: (context, i) {
          final p = kPeople[i];
          return ListTile(
            onTap: () => Navigator.push(context, UserProfileScreen.route(p)),
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Colors.black,
              child: Icon(LucideIcons.user, color: Colors.white),
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(p.handle, style: const TextStyle(color: Color(0xFF8E8E8E))),
            trailing: FollowButton(handle: p.handle, compact: true),
          );
        },
      ),
    );
  }
}


