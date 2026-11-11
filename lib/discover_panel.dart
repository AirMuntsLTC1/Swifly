import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'native_bridge.dart';
import 'post_model.dart';
import 'tag_friends_screen.dart';

const List<String> kTrendingTags = [
  'travel',
  'coffee',
  'coding',
  'design',
  'hiking',
  'books',
];

/// Mock follower and following counts per handle. Replace with database values later.
const Map<String, (int, int)> kPeopleStats = {
  '@avastone': (1243, 310),
  '@liampark': (856, 402),
  '@miachen': (3120, 198),
  '@noahreed': (412, 260),
  '@zaraali': (9800, 121),
  '@ethanb': (67, 88),
  '@sofial': (2210, 540),
  '@maxturner': (533, 97),
  '@hanasato': (1540, 376),
  '@omarkh': (98, 143),
};

class DiscoverPanel extends StatefulWidget {
  final String query;
  const DiscoverPanel({super.key, required this.query});

  @override
  State<DiscoverPanel> createState() => _DiscoverPanelState();
}

class _DiscoverPanelState extends State<DiscoverPanel> {
  final Map<String, int> _followers = {
    for (final f in kFriends) f.handle: kPeopleStats[f.handle]?.$1 ?? 0,
  };
  final Map<String, int> _following = {
    for (final f in kFriends) f.handle: kPeopleStats[f.handle]?.$2 ?? 0,
  };
  final Set<String> _followed = {};

  void _toggleFollow(String handle) {
    setState(() {
      if (_followed.remove(handle)) {
        _followers[handle] = (_followers[handle] ?? 1) - 1;
      } else {
        _followed.add(handle);
        _followers[handle] = (_followers[handle] ?? 0) + 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query.trim();
    if (q.isEmpty) return _browse();
    return _results(q);
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
    );
  }

  Widget _empty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(message, style: const TextStyle(color: Color(0xFF8E8E8E))),
    );
  }

  Widget _browse() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _title('Discover'),
        _title('Trending'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final t in kTrendingTags) _tagChip(t)],
          ),
        ),
        _title('People to follow'),
        for (final f in kFriends) _personTile(f),
      ],
    );
  }

  Widget _results(String q) {
    final people = kFriends
        .where((f) =>
            NativeCore.containsCI(f.name, q) || NativeCore.containsCI(f.handle, q))
        .toList();
    final posts = PostStore.instance.search(q);
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _title('People'),
        if (people.isEmpty)
          _empty('No people match "$q"')
        else
          for (final f in people) _personTile(f),
        _title('Posts'),
        if (posts.isEmpty)
          _empty('No posts match "$q"')
        else
          for (final p in posts) _postSnippet(p),
      ],
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.hash, size: 14, color: Colors.black),
          const SizedBox(width: 4),
          Text(tag,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _personTile(Friend f) {
    final followers = _followers[f.handle] ?? 0;
    final following = _following[f.handle] ?? 0;
    final isFollowing = _followed.contains(f.handle);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: const CircleAvatar(
        backgroundColor: Colors.black,
        child: Icon(LucideIcons.user, color: Colors.white, size: 20),
      ),
      title: Text(f.name,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(f.handle, style: const TextStyle(color: Color(0xFF8E8E8E))),
          const SizedBox(height: 3),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              '${NativeCore.formatCount(followers)} followers · '
              '${NativeCore.formatCount(following)} following',
              key: ValueKey('$followers-$following'),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
            ),
          ),
        ],
      ),
      trailing: _FollowButton(
        following: isFollowing,
        onTap: () => _toggleFollow(f.handle),
      ),
    );
  }

  Widget _postSnippet(Post p) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const CircleAvatar(
        backgroundColor: Colors.black,
        child: Icon(LucideIcons.newspaper, color: Colors.white, size: 18),
      ),
      title: Text(p.authorName,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
      subtitle: Text(p.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF6E6E6E))),
      trailing: Text(p.timeLabel,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
    );
  }
}

/// Follow button: squeezes on press, then the color and label animate to the new state.
class _FollowButton extends StatefulWidget {
  final bool following;
  final VoidCallback onTap;

  const _FollowButton({required this.following, required this.onTap});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.following;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.black,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.black),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              on ? 'Following' : 'Follow',
              key: ValueKey<bool>(on),
              style: TextStyle(
                color: on ? Colors.black : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
