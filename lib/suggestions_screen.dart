import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'tag_friends_screen.dart';

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
        itemCount: kFriends.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFFEAEAEA)),
        itemBuilder: (context, i) {
          final f = kFriends[i];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Colors.black,
              child: Icon(LucideIcons.user, color: Colors.white),
            ),
            title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(f.handle, style: const TextStyle(color: Color(0xFF8E8E8E))),
            trailing: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D6FDC),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Follow', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          );
        },
      ),
    );
  }
}
