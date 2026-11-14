import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'chat_screen.dart';
import 'connections_screen.dart';
import 'database_service.dart';
import 'db_mappers.dart';
import 'dm_theme.dart';
import 'follow_button.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'nav_guard.dart';
import 'native_bridge.dart';
import 'people_directory.dart';
import 'post_model.dart';
import 'profile_details_section.dart';
import 'feed_widgets.dart';
import 'profile_store.dart';
import 'responsive.dart';
import 'story_player_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final Person user;
  const UserProfileScreen({super.key, required this.user});

  static Route<void> route(Person user) => fastRoute<void>(
        name: 'profile:${user.handle}',
        child: UserProfileScreen(user: user),
      );

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String? _userId;
  int _followers = 0;
  int _following = 0;
  List<Post> _posts = const [];
  bool _postsLoaded = false;
  Map<String, ProfileField> _details = const {};
  bool _detailsLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    FollowStore.instance.addListener(_loadCounts);
  }

  @override
  void dispose() {
    FollowStore.instance.removeListener(_loadCounts);
    super.dispose();
  }

  /// Everything on this profile comes from the database: counts, posts and the
  /// personal details this viewer may see. The follow lists are fetched early too.
  Future<void> _load() async {
    _userId = await DatabaseService.instance.idForHandle(widget.user.handle);
    prefetchConnections(widget.user.handle);
    await Future.wait([_loadCounts(), _loadPosts(), _loadDetails()]);
  }

  Future<void> _loadCounts() async {
    try {
      final c = await DatabaseService.instance.fetchProfileCounts(widget.user.handle);
      if (!mounted) return;
      setState(() {
        _followers = c['followers'] ?? 0;
        _following = c['following'] ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _loadPosts() async {
    final id = _userId;
    if (id != null) {
      try {
        final rows = await DatabaseService.instance.fetchPosts(limit: 200, offset: 0, authorId: id);
        final loaded = [for (final r in rows) postFromRow(r)];
        PostStore.instance.remember(loaded);
        if (mounted) setState(() => _posts = loaded);
      } catch (_) {}
    }
    if (mounted) setState(() => _postsLoaded = true);
  }

  Future<void> _loadDetails() async {
    try {
      final rows = await DatabaseService.instance.fetchProfileFieldsOf(widget.user.handle);
      final known = {for (final s in kProfileSections) for (final d in s.fields) d.key};
      final followed = FollowStore.instance.isFollowing(widget.user.handle);
      final out = <String, ProfileField>{};
      for (final r in rows) {
        final key = r['key'] ?? '';
        if (!known.contains(key)) continue;
        final audience = Audience.values.firstWhere(
          (a) => a.name == r['audience'],
          orElse: () => Audience.everyone,
        );
        // The database already hides private fields. This is a second check on the device.
        if (!NativeCore.canSee(audience.index, isOwner: false, viewerFollowsOwner: followed)) continue;
        out[key] = ProfileField(value: (r['value'] ?? '').trim(), audience: audience);
      }
      if (mounted) setState(() => _details = out);
    } catch (_) {}
    if (mounted) setState(() => _detailsLoaded = true);
  }

  String get _bio => (_details['bio']?.value ?? '').trim();

  /// Profile picture. With a story it gets a blue ring and opens the story.
  Widget _storyAvatar(BuildContext context, Person f, R r) {
    final avatar = DmAvatar(handle: f.handle, name: f.name, size: r.s(88));
    final story = StoryStore.instance.otherStory(f.handle);
    if (story == null) return avatar;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryPlayerScreen(
            data: story.data,
            name: f.name,
            handle: f.handle,
            time: story.time,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1D6FDC), width: 3),
        ),
        child: avatar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.user;
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
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(r.pad, 10, r.pad, 96),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _storyAvatar(context, f, r),
              const SizedBox(height: 14),
              Text(
                f.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black),
              ),
              const SizedBox(height: 4),
              Text(f.handle, style: const TextStyle(color: Color(0xFF8E8E8E))),
              if (_bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_bio, style: const TextStyle(fontSize: 15, color: Colors.black)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  _Stat(label: 'Posts', value: _postsLoaded ? '${_posts.length}' : '…'),
                  const SizedBox(width: 32),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => pushOnce(
                      context,
                      fastRoute(
                        name: 'connections:${f.handle}:followers',
                        child: ConnectionsScreen(initialFollowers: true, userHandle: f.handle, userName: f.name),
                      ),
                    ),
                    child: _Stat(label: 'Followers', value: NativeCore.formatCount(_followers)),
                  ),
                  const SizedBox(width: 32),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => pushOnce(
                      context,
                      fastRoute(
                        name: 'connections:${f.handle}:following',
                        child: ConnectionsScreen(initialFollowers: false, userHandle: f.handle, userName: f.name),
                      ),
                    ),
                    child: _Stat(label: 'Following', value: NativeCore.formatCount(_following)),
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
                      onPressed: () => pushOnce(
                        context,
                        fastRoute(name: 'chat:${f.handle}', child: ChatScreen(handle: f.handle)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D6FDC),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        minimumSize: const Size(0, 48),
                        maximumSize: const Size(double.infinity, 48),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                      ),
                      child: const Text(
                        'Message',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _detailsSection(),
              const SizedBox(height: 30),
              const Text(
                'Posts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black),
              ),
              const SizedBox(height: 12),
              _postsSection(),
              const SizedBox(height: 30),
              _suggestionsSection(r),
            ],
          ),
        ),
      ),
    );
  }

  /// Only the details this viewer may see, read-only, with the same layout as your own profile.
  Widget _detailsSection() {
    if (!_detailsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
      );
    }
    final hasDetails = _details.entries.any((e) => e.key != 'bio' && e.value.value.isNotEmpty);
    if (!hasDetails) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No personal details shared with you', style: TextStyle(color: Color(0xFF8E8E8E))),
      );
    }
    return ProfileDetailsSection(fields: _details);
  }

  Widget _postsSection() {
    if (!_postsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
      );
    }
    if (_posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No posts yet', style: TextStyle(color: Color(0xFF8E8E8E))),
      );
    }
    // Rebuilds when a like or save changes on any of these posts.
    return ListenableBuilder(
      listenable: PostStore.instance,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final p in _posts) PostCard(key: ValueKey(p.id), post: p)],
      ),
    );
  }

  /// People to follow next: never people you already follow, and never people who follow you.
  Widget _suggestionsSection(R r) {
    return ListenableBuilder(
      listenable: Listenable.merge([FollowStore.instance, PeopleDirectory.instance]),
      builder: (context, _) {
        final list = [
          for (final p in FollowStore.instance.suggestedPeople())
            if (p.handle != widget.user.handle) p,
        ].take(10).toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Suggestions People',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: r.h(190),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemBuilder: (context, i) => _SuggestionCard(friend: list[i]),
              ),
            ),
          ],
        );
      },
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
      onTap: () => pushOnce(context, UserProfileScreen.route(friend)),
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
            DmAvatar(handle: friend.handle, name: friend.name, size: 60),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                friend.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                friend.handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
              ),
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
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 13)),
      ],
    );
  }
}
