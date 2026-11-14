import 'dart:io';

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

  /// Loads the counts, then this person's posts. Counts come from the database,
  /// so they are right even if this person is not in the phone's cache.
  Future<void> _load() async {
    _userId = await DatabaseService.instance.idForHandle(widget.user.handle);
    await _loadCounts();
    await _loadPosts();
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
    if (id == null) {
      if (mounted) setState(() => _postsLoaded = true);
      return;
    }
    try {
      final rows = await DatabaseService.instance.fetchPosts(limit: 50, offset: 0, authorId: id);
      if (mounted) setState(() => _posts = [for (final r in rows) postFromRow(r)]);
    } catch (_) {}
    if (mounted) setState(() => _postsLoaded = true);
  }

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
              const SizedBox(height: 20),
              Row(
                children: [
                  _Stat(label: 'Posts', value: _postsLoaded ? '${_posts.length}' : '…'),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTap: () => pushOnce(
                      context,
                      fastRoute(
                        name: 'connections:${f.handle}:followers',
                        child: ConnectionsScreen(
                          initialFollowers: true,
                          userHandle: f.handle,
                          userName: f.name,
                        ),
                      ),
                    ),
                    child: _Stat(label: 'Followers', value: NativeCore.formatCount(_followers)),
                  ),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTap: () => pushOnce(
                      context,
                      fastRoute(
                        name: 'connections:${f.handle}:following',
                        child: ConnectionsScreen(
                          initialFollowers: false,
                          userHandle: f.handle,
                          userName: f.name,
                        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final p in _posts) _ProfilePostCard(post: p)],
    );
  }

  /// People to follow next, from the same rule as Discover: never people you
  /// already follow, and never people who already follow you.
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

/// One of this person's posts: picture (if any), text, and the like and comment counts.
class _ProfilePostCard extends StatelessWidget {
  final Post post;
  const _ProfilePostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final media = post.media.isNotEmpty ? post.media.first : null;
    final preview = media?.previewPath;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(
                File(preview),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF2F2F2)),
              ),
            ),
          if (post.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Text(
                post.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black, fontSize: 15),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                const Icon(LucideIcons.heart, size: 14, color: Color(0xFF8E8E8E)),
                const SizedBox(width: 4),
                Text('${post.likes}', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
                const SizedBox(width: 14),
                const Icon(LucideIcons.messageCircle, size: 14, color: Color(0xFF8E8E8E)),
                const SizedBox(width: 4),
                Text('${post.totalComments}', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
                const Spacer(),
                Text(post.timeLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
              ],
            ),
          ),
        ],
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
