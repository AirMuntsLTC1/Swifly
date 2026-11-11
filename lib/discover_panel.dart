import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'hashtag_screen.dart';
import 'native_bridge.dart';
import 'post_model.dart';
import 'search_history.dart';
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
  final ValueChanged<String> onPickQuery;

  const DiscoverPanel({
    super.key,
    required this.query,
    required this.onPickQuery,
  });

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

  Widget _recentHeader(bool hasItems) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          const Text('Recent',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black)),
          const Spacer(),
          if (hasItems)
            GestureDetector(
              onTap: _confirmRemoveAll,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Remove all',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D6FDC)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _browse() {
    return ListenableBuilder(
      listenable:
          Listenable.merge([SearchHistory.instance, PostStore.instance]),
      builder: (context, _) {
        final recents = SearchHistory.instance.items;
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _recentHeader(recents.isNotEmpty),
            if (recents.isEmpty)
              _empty('No recent searches')
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final r in recents) _recentChip(r)],
                ),
              ),
            _title('Trending'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final t in kTrendingTags) _trendChip(t)],
              ),
            ),
            _title('People to follow'),
            for (final f in kFriends) _personTile(f),
          ],
        );
      },
    );
  }

  Widget _recentChip(String query) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => widget.onPickQuery(query),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.clock, size: 14, color: Colors.black),
            const SizedBox(width: 6),
            Text(query,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _trendChip(String tag) {
    final hashtag = '#' + tag.toLowerCase();
    final postCount = PostStore.instance.postsWithHashtag(hashtag).length;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => Navigator.of(context).push(hashtagRoute(hashtag)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF5FF),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hashtag,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D6FDC))),
            const SizedBox(width: 6),
            Text(
              NativeCore.formatCount(postCount),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6E7B90)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(String q) {
    final people = kFriends
        .where((f) =>
            NativeCore.containsCI(f.name, q) ||
            NativeCore.containsCI(f.handle, q))
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

  Future<void> _confirmRemoveAll() async {
    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Are you sure to remove all recents',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _dialogButton(
                        label: 'Yes',
                        color: Colors.red,
                        onTap: () => Navigator.pop(dialogContext, true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dialogButton(
                        label: 'Cancel',
                        color: Colors.black,
                        onTap: () => Navigator.pop(dialogContext, false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (ok == true) {
      SearchHistory.instance.clear();
    }
  }

  Widget _dialogButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: Colors.black)),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
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
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: Colors.black)),
      subtitle: Text(p.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF6E6E6E))),
      trailing: Text(p.timeLabel,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
    );
  }
}

/// Follow button: squeezes on press, then color and label animate to the new state.
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
