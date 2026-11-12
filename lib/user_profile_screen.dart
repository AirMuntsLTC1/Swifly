import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'connections_screen.dart';
import 'native_bridge.dart';
import 'post_model.dart';
import 'follow_button.dart';
import 'tag_friends_screen.dart';
import 'discover_panel.dart';
import 'responsive.dart';

class UserProfileScreen extends StatefulWidget {
  final Person user;
  const UserProfileScreen({super.key, required this.user});

  static Route<void> route(Person user) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => UserProfileScreen(user: user),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final f = widget.user;
    final stats = kPeopleStats[f.handle] ?? (0, 0);
    final r = R.of(context);

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
        title: Text(
          f.handle,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(r.pad, 10, r.pad, 96),
        child: ContentWidth(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: r.s(44),
              backgroundColor: Colors.black,
              child: Icon(LucideIcons.user, color: Colors.white, size: r.s(40)),
            ),
            const SizedBox(height: 14),
            Text(f.name,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black)),
            const SizedBox(height: 4),
            Text(f.handle, style: const TextStyle(color: Color(0xFF8E8E8E))),
            const SizedBox(height: 10),
            const Text('Living life one step at a time. Exploring the world.',
                style: TextStyle(color: Colors.black, height: 1.4)),
            const SizedBox(height: 20),
            Row(
              children: [
                const _Stat(label: 'Posts', value: '12'),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ConnectionsScreen(
                            initialFollowers: true,
                            userHandle: f.handle,
                            userName: f.name)),
                  ),
                  child: _Stat(
                      label: 'Followers',
                      value: NativeCore.formatCount(stats.$1)),
                ),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ConnectionsScreen(
                            initialFollowers: false,
                            userHandle: f.handle,
                            userName: f.name)),
                  ),
                  child: _Stat(
                      label: 'Following',
                      value: NativeCore.formatCount(stats.$2)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: FollowButton(handle: f.handle, expand: true)),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Messaging ${f.name}')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D6FDC),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Message',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                const Text('Suggestions People',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black)),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: r.h(190),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: kPeople.take(10).length,
                itemBuilder: (context, i) {
                  final suggest = kPeople[i];
                  if (suggest.handle == f.handle)
                    return const SizedBox.shrink();
                  return _SuggestionCard(friend: suggest);
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Person friend;
  const _SuggestionCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(context, UserProfileScreen.route(friend)),
      child: Container(
        width: r.w(130),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAEAEA)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.black,
              child: Icon(LucideIcons.user, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              friend.name,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              friend.handle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FollowButton(handle: friend.handle, compact: true, expand: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 13)),
      ],
    );
  }
}


