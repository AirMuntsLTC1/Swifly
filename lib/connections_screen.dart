import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'database_service.dart';
import 'db_mappers.dart';
import 'follow_button.dart';
import 'follow_store.dart';
import 'nav_guard.dart';
import 'people_directory.dart';
import 'person_row.dart';
import 'user_profile_screen.dart';

/// Lists loaded earlier this session. A list opened again shows at once,
/// then refreshes in the background.
final Map<String, List<Person>> _listMemo = <String, List<Person>>{};

String _memoKey(String handle, bool followers) => '$handle|$followers';

Future<List<Person>> _fetchRemote(String handle, bool followers) async {
  final rows = await DatabaseService.instance.fetchConnections(handle, followers: followers);
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
}

/// Loads both tabs of another person's lists in the background. Called when
/// their profile opens, so the lists are already there when tapped.
Future<void> prefetchConnections(String handle) async {
  for (final followers in [true, false]) {
    try {
      _listMemo[_memoKey(handle, followers)] = await _fetchRemote(handle, followers);
    } catch (_) {}
  }
}

/// Followers and Following lists.
/// - Your own lists come from FollowStore, which is reloaded from the database when opened.
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
  List<Person>? _remoteItems;
  bool _remoteFailed = false;
  int _loadId = 0;

  bool get _isOtherPerson => widget.userHandle != null && widget.userHandle != kMeHandle;

  @override
  void initState() {
    super.initState();
    _showFollowers = widget.initialFollowers;
    if (_isOtherPerson) {
      _startRemote();
    } else {
      FollowStore.instance.refresh();
    }
  }

  /// Shows the saved copy at once (if any) and fetches the current list.
  /// Only the newest request is allowed to update the screen.
  void _startRemote() {
    final handle = widget.userHandle!;
    final followers = _showFollowers;
    final id = ++_loadId;
    _remoteItems = _listMemo[_memoKey(handle, followers)];
    _remoteFailed = false;
    _fetchRemote(handle, followers).then((people) {
      _listMemo[_memoKey(handle, followers)] = people;
      if (!mounted || id != _loadId) return;
      setState(() => _remoteItems = people);
    }).catchError((_) {
      if (!mounted || id != _loadId) return;
      setState(() => _remoteFailed = _remoteItems == null);
    });
  }

  void _setTab(bool followers) {
    setState(() {
      _showFollowers = followers;
      if (_isOtherPerson) _startRemote();
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
                Expanded(child: _buildTabButton('Followers', _showFollowers, () => _setTab(true))),
                const SizedBox(width: 12),
                Expanded(child: _buildTabButton('Following', !_showFollowers, () => _setTab(false))),
              ],
            ),
          ),
          Expanded(child: _isOtherPerson ? _remoteBody() : _myList()),
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
        return _renderPeople([for (final h in handles) personFor(h)]);
      },
    );
  }

  Widget _remoteBody() {
    final items = _remoteItems;
    if (items != null) return _renderPeople(items);
    if (_remoteFailed) {
      return const Center(
        child: Text('Could not load this list. Check your connection.',
            textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8E8E8E))),
      );
    }
    return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black));
  }

  Widget _renderPeople(List<Person> people) {
    if (people.isEmpty) {
      return Center(
        child: Text(
          _showFollowers ? 'No followers yet' : 'Not following anyone yet',
          style: const TextStyle(color: Color(0xFF8E8E8E)),
        ),
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
