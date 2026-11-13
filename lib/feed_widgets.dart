import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'hashtag_screen.dart';

import 'burst_icons.dart';
import 'native_bridge.dart';
import 'post_model.dart';
import 'user_profile_screen.dart';
import 'tag_friends_screen.dart';
import 'follow_button.dart';
import 'post_detail_screen.dart';
import 'media/post_media_view.dart';
import 'share_sheet.dart';

class FeedTab extends StatelessWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PostStore.instance,
      builder: (context, _) {
        final posts = PostStore.instance.ranked;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: posts.length,
          itemBuilder: (context, i) =>
              PostCard(key: ValueKey(posts[i].id), post: posts[i]),
        );
      },
    );
  }
}

class PostCard extends StatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _heartBurst = 0;
  int _shareBurst = 0;
  final List<TapGestureRecognizer> _recognizers = [];
  late TextSpan _textSpan;

  @override
  void initState() {
    super.initState();
    _buildTextSpan();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.text != widget.post.text) {
      _buildTextSpan();
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _buildTextSpan() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.post.text;
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(#[a-zA-Z0-9_]+)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      final hashtag = match.group(0)!;
      final recognizer = TapGestureRecognizer();
      _recognizers.add(recognizer);
      recognizer.onTap = () {
        if (mounted) HashtagScreen.navigate(context, hashtag);
      };
      spans.add(TextSpan(
        text: hashtag,
        style: const TextStyle(
            color: Color(0xFF1D6FDC), fontWeight: FontWeight.w600),
        recognizer: recognizer,
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    _textSpan = TextSpan(
      style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black),
      children: spans,
    );
  }

  void _onLike() {
    PostStore.instance.toggleLike(widget.post.id);
    if (widget.post.liked) setState(() => _heartBurst++);
  }

  void _onShare() {
    setState(() => _shareBurst++);
    // Let the paper plane animation start, then open the dialog.
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (mounted) showSharePostDialog(context, widget.post);
    });
  }

  IconData _audienceIcon(String audience) {
    switch (audience) {
      case 'Only me':
        return LucideIcons.lock;
      case 'Followers':
        return LucideIcons.users;
      default:
        return LucideIcons.globe;
    }
  }

  Widget _header(Post p) {
    final tagNames = p.taggedHandles.map(nameForHandle).toList();
    Person? author;
    for (final f in kPeople) {
      if (f.handle == p.authorHandle) author = f;
    }

    return InkWell(
      onTap: author != null
          ? () => Navigator.push(context, UserProfileScreen.route(author!))
          : null,
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 20,
          backgroundColor: Colors.black,
          child: Icon(LucideIcons.user, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.authorName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(_audienceIcon(p.audience), size: 12, color: const Color(0xFF8E8E8E)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${p.authorHandle} · ${p.timeLabel} · ${p.audience}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E)),
                    ),
                  ),
                ],
              ),
              if (tagNames.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'with ${tagNames.join(', ')}',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ],
          ),
        ),
        if (p.authorHandle != kMeHandle) ...[
          const SizedBox(width: 8),
          FeedFollowButton(handle: p.authorHandle),
        ],
      ],
    ),
    );
  }

  String _countsLine(Post p) {
    final likes = NativeCore.formatCount(p.likes);
    final comments = NativeCore.formatCount(p.totalComments);
    final shares = NativeCore.formatCount(p.shares);
    return '$likes likes · $comments comments · $shares shares';
  }

  Widget _pop(int burst, Widget child) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('pop_$burst'),
      tween: Tween<double>(begin: burst == 0 ? 1.0 : 0.5, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, scale, c) => Transform.scale(scale: scale, child: c),
      child: child,
    );
  }

  Widget _iconStack({
    required int burst,
    required IconData burstIcon,
    required Color burstColor,
    required Widget child,
  }) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          BurstIcons(trigger: burst, icon: burstIcon, color: burstColor),
          child,
        ],
      ),
    );
  }

  Widget _actionCell({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions(Post p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          _actionCell(
            icon: _iconStack(
              burst: _heartBurst,
              burstIcon: Icons.favorite,
              burstColor: Colors.red,
              child: _pop(
                _heartBurst,
                p.liked
                    ? const Icon(Icons.favorite, color: Colors.red, size: 22)
                    : const Icon(LucideIcons.heart, color: Colors.black, size: 22),
              ),
            ),
            label: p.liked ? 'Liked' : 'Like',
            onTap: _onLike,
          ),
          _actionCell(
            icon: const Icon(LucideIcons.messageCircle, color: Colors.black, size: 22),
            label: 'Comment',
            onTap: () => Navigator.push(context, postDetailRoute(p.id)),
          ),
          _actionCell(
            icon: _iconStack(
              burst: _shareBurst,
              burstIcon: LucideIcons.send,
              burstColor: const Color(0xFF1D6FDC),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('share_$_shareBurst'),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                builder: (context, t, c) {
                  // Plane tilts, flies up-right a little and settles back.
                  final fly = _shareBurst == 0 ? 0.0 : (t < 0.5 ? t * 2 : (1 - t) * 2);
                  return Transform.translate(
                    offset: Offset(7 * fly, -7 * fly),
                    child: Transform.rotate(angle: -0.35 * fly, child: c),
                  );
                },
                child: const Icon(LucideIcons.send, color: Colors.black, size: 22),
              ),
            ),
            label: 'Share',
            onTap: _onShare,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: _header(p),
          ),
          if (p.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: RichText(text: _textSpan),
            ),
          if (p.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: PostMediaView(postId: p.id, media: p.media),
            ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(_countsLine(p),
                style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFEAEAEA)),
          _actions(p),
          Container(height: 8, color: const Color(0xFFF2F2F2)),
        ],
      ),
    );
  }
}

class FeedFollowButton extends StatelessWidget {
  final String handle;
  const FeedFollowButton({super.key, required this.handle});

  @override
  Widget build(BuildContext context) => FollowButton(handle: handle, compact: true);
}
