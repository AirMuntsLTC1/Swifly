import 'package:flutter/material.dart';
import 'nav_guard.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'follow_button.dart';
import 'follow_store.dart';
import 'post_model.dart';
import 'user_profile_screen.dart';
import 'people_directory.dart';

/// Followers and Following lists. Both come from [FollowStore], so they update
/// live when someone follows or unfollows.
/// Currently shows the signed-in user's lists; [userHandle] is kept for when
/// other people's lists come from the database.
class ConnectionsScreen extends StatefulWidget {
  final bool initialFollowers;
  // Optional. Not used yet. Defaults cannot read kMeHandle/kMeName here because
  // those values are only known at runtime, not at compile time.
  final String? userHandle;
  final String? userName;
  const ConnectionsScreen({
    super.key,
    required this.initialFollowers,
    this.userHandle,
    this.userName,
  });

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  late bool _showFollowers;

  @override
  void initState() {
    super.initState();
    _showFollowers = widget.initialFollowers;
  }

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
        title: Text(
          _showFollowers ? 'Followers' : 'Following',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('Followers', _showFollowers, () {
                    setState(() => _showFollowers = true);
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton('Following', !_showFollowers, () {
                    setState(() => _showFollowers = false);
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: FollowStore.instance,
              builder: (context, _) {
                final handles = (_showFollowers
                        ? FollowStore.instance.followerHandles
                        : FollowStore.instance.followingHandles)
                    .toList();
                if (handles.isEmpty) {
                  return Center(
                    child: Text(
                      _showFollowers ? 'No followers yet' : 'Not following anyone yet',
                      style: const TextStyle(color: Color(0xFF8E8E8E)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: handles.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFFEAEAEA)),
                  itemBuilder: (context, i) {
                    final p = personFor(handles[i]);
                    return ListTile(
                      onTap: () => pushOnce(context, UserProfileScreen.route(p)),
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Colors.black,
                        child: Icon(LucideIcons.user, color: Colors.white),
                      ),
                      title: Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(p.handle,
                          style: const TextStyle(color: Color(0xFF8E8E8E))),
                      trailing: FollowButton(handle: p.handle, compact: true),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }
}



