import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'tag_friends_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  final bool initialFollowers;
  const ConnectionsScreen({super.key, required this.initialFollowers});

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
        title: const Text(
          'Connections',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
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
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Follow'),
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
