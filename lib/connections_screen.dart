import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'tag_friends_screen.dart';
import 'user_profile_screen.dart';
import 'post_model.dart';

class ConnectionsScreen extends StatefulWidget {
  final bool initialFollowers;
  final String userHandle;
  final String userName;
  const ConnectionsScreen({
    super.key,
    required this.initialFollowers,
    this.userHandle = kMeHandle,
    this.userName = kMeName,
  });

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  late bool _showFollowers;

  // Split the friends list into two different lists for the demo
  final List<Friend> _followersList = kFriends.sublist(0, 5);
  final List<Friend> _followingList = kFriends.sublist(5, 10);

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
          '${widget.userName}\'s Connections',
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
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: (_showFollowers ? _followersList : _followingList).length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFFEAEAEA)),
              itemBuilder: (context, i) {
                final f = (_showFollowers ? _followersList : _followingList)[i];
                return ListTile(
                  onTap: () => Navigator.push(context, UserProfileScreen.route(f)),
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
