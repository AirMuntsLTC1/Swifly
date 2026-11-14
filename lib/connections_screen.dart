import 'package:flutter/material.dart';
import 'nav_guard.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'database_service.dart';
import 'db_mappers.dart';
import 'follow_button.dart';
import 'follow_store.dart';
import 'people_directory.dart';
import 'person_row.dart';
import 'user_profile_screen.dart';

/// Followers and Following lists.
///
/// - Your own lists (no [userHandle], or your handle) come from [FollowStore] and update live.
/// - Another person's lists come from the database, for that person.
class ConnectionsScreen extends StatefulWidget {
  final bool initialFollowers;
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
  Future<List<Person>>? _remote;

  bool get _isOtherPerson => widget.userHandle != null && widget.userHandle != kMeHandle;

  @override
  void initState() {
    super.initState();
    _showFollowers = widget.initialFollowers;
    _reloadRemote();
  }

  /// Loads the other person's list for the current tab. Also merges the people into the directory.
  void _reloadRemote() {
    if (!_isOtherPerson) {
      _remote = null;
      return;
    }
    _remote = DatabaseService.instance
        .fetchConnections(widget.userHandle!, followers: _showFollowers)
        .then((rows) {
      final people = [for (final r in rows) personFromRow(r)];
      final stats = <String, (int, int)>{
        for (final r in rows)
          '${r['handle']}': (
            (r['followers_count'] as num?)?.toInt() ?? 0,
            (r['following_count'] as num?)?.toInt() ?? 0,
          ),
      };
      PeopleDirectory.instance.merge(people: people, stats: stats);
      return people;
    });
  }

  void _setTab(bool followers) {
    setState(() {
      _showFollowers = followers;
      _reloadRemote();
    });
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
                  child: _buildTabButton('Followers', _showFollowers, () => _setTab(true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton('Following', !_showFollowers, () => _setTab(false)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isOtherPerson ? _remoteList() : _myList(),
          ),
        ],
      ),
    );
  }

  /// Your own list, live from FollowStore.
  Widget _myList() {
    return ListenableBuilder(
      listenable: FollowStore.instance,
      builder: (context, _) {
        final handles = (_showFollowers
                ? FollowStore.instance.followerHandles
                : FollowStore.instance.followingHandles)
            .toList();
        return _renderPeople([for (final h in handles) personFor(h)], _emptyText());
      },
    );
  }

  /// Another person's list, from the database.
  Widget _remoteList() {
    return FutureBuilder<List<Person>>(
      future: _remote,
      builder: (context, snap) {
        if (snap.hasData) return _renderPeople(snap.data!, _emptyText());
        if (snap.hasError) {
          return const Center(
            child: Text('Could not load this list. Check your connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E8E8E))),
          );
        }
        return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black));
      },
    );
  }

  String _emptyText() => _showFollowers ? 'No followers yet' : 'Not following anyone yet';

  Widget _renderPeople(List<Person> people, String emptyText) {
    if (people.isEmpty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: Color(0xFF8E8E8E))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: people.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEAEAEA)),
      itemBuilder: (context, i) {
        final p = people[i];
        return PersonRow(
          person: p,
          onTap: () => pushOnce(context, UserProfileScreen.route(p)),
          trailing: FollowButton(handle: p.handle, compact: true),
        );
      },
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
