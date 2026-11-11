import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'hashtag_screen.dart';

import 'burst_icons.dart';
import 'native_bridge.dart';
import 'post_model.dart';
import 'user_profile_screen.dart';
import 'tag_friends_screen.dart';

const Color _saveOrange = Color(0xFFFF9800);

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
  int _saveBurst = 0;
  final List<TapGestureRecognizer> _recognizers = [];
  late TextSpan _textSpan;
  int _currentPage = 0;

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

  void _onSave() {
    PostStore.instance.toggleSave(widget.post.id);
    if (widget.post.saved) setState(() => _saveBurst++);
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
    Friend? author;
    for (final f in kFriends) {
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
    final comments = NativeCore.formatCount(p.comments.length);
    final saves = NativeCore.formatCount(p.saves);
    return '$likes likes · $comments comments · $saves saves';
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
            onTap: () => showCommentsSheet(context, p.id),
          ),
          _actionCell(
            icon: _iconStack(
              burst: _saveBurst,
              burstIcon: Icons.bookmark,
              burstColor: _saveOrange,
              child: _pop(
                _saveBurst,
                p.saved
                    ? const Icon(Icons.bookmark, color: _saveOrange, size: 22)
                    : const Icon(LucideIcons.bookmark, color: Colors.black, size: 22),
              ),
            ),
            label: p.saved ? 'Saved' : 'Save',
            onTap: _onSave,
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
          if (p.mediaPaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: p.mediaPaths.length == 1
                    ? AspectRatio(
                        aspectRatio: 1, // Instagram style square
                        child: Image.file(
                          File(p.mediaPaths.first),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF2F2F2),
                            alignment: Alignment.center,
                            child: const Icon(LucideIcons.image, color: Colors.grey),
                          ),
                        ),
                      )
                    : Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          AspectRatio(
                            aspectRatio: 1, // Instagram style square
                            child: PageView.builder(
                              onPageChanged: (index) {
                                setState(() => _currentPage = index);
                              },
                              itemCount: p.mediaPaths.length,
                              itemBuilder: (context, index) {
                                return Image.file(
                                  File(p.mediaPaths[index]),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  cacheWidth: 800,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFF2F2F2),
                                    alignment: Alignment.center,
                                    child: const Icon(LucideIcons.image, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Instagram-style dots indicator
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                p.mediaPaths.length,
                                (index) => Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentPage == index
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
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

void showCommentsSheet(BuildContext context, String postId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CommentsSheet(postId: postId),
  );
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Set<String> _expanded = {};
  CommentItem? _replyingTo;
  bool _showEmojiPicker = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final target = _replyingTo;
    if (target == null) {
      PostStore.instance.addComment(widget.postId, text);
    } else {
      PostStore.instance.addReply(widget.postId, target.id, text);
      setState(() => _expanded.add(target.id));
    }
    _controller.clear();
    setState(() => _replyingTo = null);
  }

  void _toggleReplies(String id) {
    setState(() {
      if (!_expanded.remove(id)) _expanded.add(id);
    });
  }

  void _toggleEmoji() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  Widget _avatar(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.black,
      child: Icon(LucideIcons.user, color: Colors.white, size: radius * 0.9),
    );
  }

  Widget _commentTile(CommentItem c, {required bool isReply}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 10 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(isReply ? 13 : 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isReply ? 13 : 14,
                        color: Colors.black)),
                const SizedBox(height: 2),
                Text(c.text,
                    style: TextStyle(
                        fontSize: isReply ? 13 : 14, color: Colors.black)),
                if (!isReply)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyingTo = c;
                        _showEmojiPicker = false;
                      });
                      _focusNode.requestFocus();
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Reply',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8E8E8E))),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thread(CommentItem c) {
    final expanded = _expanded.contains(c.id);
    final replies = c.replies;
    final hasMore = replies.length > 1;
    final visible = expanded ? replies : replies.take(1).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _commentTile(c, isReply: false),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final r in visible) _commentTile(r, isReply: true),
                      ],
                    ),
                  ),
                  if (hasMore)
                    GestureDetector(
                      onTap: () => _toggleReplies(c.id),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          expanded
                              ? 'Hide replies'
                              : 'See all ${replies.length} replies',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(Post? post, int totalComments) {
    final likes = NativeCore.formatCount(post?.likes ?? 0);
    final comments = NativeCore.formatCount(totalComments);
    const countStyle = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      child: Row(
        children: [
          const Text('Comments',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(width: 12),
          const Icon(LucideIcons.heart, size: 15, color: Colors.black),
          const SizedBox(width: 4),
          Text(likes, style: countStyle),
          const SizedBox(width: 12),
          const Icon(LucideIcons.messageCircle, size: 15, color: Colors.black),
          const SizedBox(width: 4),
          Text(comments, style: countStyle),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(LucideIcons.x, color: Colors.black),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: _showEmojiPicker ? 0 : media.viewInsets.bottom),
        child: SizedBox(
          height: media.size.height * 0.7,
          child: ListenableBuilder(
            listenable: PostStore.instance,
            builder: (context, _) {
              final post = PostStore.instance.byId(widget.postId);
              final comments = post?.comments ?? const <CommentItem>[];
              var total = comments.length;
              for (final c in comments) {
                total += c.replies.length;
              }
              final replyTo = _replyingTo;
              return Column(
                children: [
                  _header(post, total),
                  const Divider(height: 1, color: Color(0xFFEAEAEA)),
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(
                            child: Text('No comments yet',
                                style: TextStyle(color: Color(0xFF8E8E8E))),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [for (final c in comments) _thread(c)],
                          ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEAEAEA)),
                  if (replyTo != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Replying to ${replyTo.name}',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF8E8E8E))),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _replyingTo = null),
                            child: const Icon(LucideIcons.x,
                                size: 16, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onTap: () {
                              if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                            },
                            cursorColor: Colors.black,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: replyTo == null
                                  ? 'Write a comment'
                                  : 'Write a reply',
                              filled: true,
                              fillColor: const Color(0xFFF2F2F2),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              border: const OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(30)),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Emoji',
                          onPressed: _toggleEmoji,
                          icon: Icon(
                              _showEmojiPicker ? LucideIcons.keyboard : LucideIcons.smile,
                              color: Colors.black),
                        ),
                        IconButton(
                          tooltip: 'Send',
                          onPressed: _send,
                          icon: const Icon(LucideIcons.send, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  if (_showEmojiPicker)
                    SizedBox(
                      height: 250,
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          _controller.text += emoji.emoji;
                        },
                        config: const Config(
                          height: 256,
                          checkPlatformCompatibility: true,
                          emojiViewConfig: EmojiViewConfig(
                            columns: 8,
                            emojiSizeMax: 32,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}


class FeedFollowButton extends StatelessWidget {
  final String handle;
  const FeedFollowButton({super.key, required this.handle});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PostStore.instance,
      builder: (context, _) {
        final status = PostStore.instance.getFollowStatus(handle);
        if (status == 3) return const SizedBox.shrink(); // Mutual, hide button

        String label = 'Follow';
        Color bg = const Color(0xFF1D6FDC);
        Color fg = Colors.white;
        Border? border;

        if (status == 1) { // Following
          label = 'Following';
          bg = Colors.white;
          fg = const Color(0xFF1D6FDC);
          border = Border.all(color: const Color(0xFF1D6FDC));
        } else if (status == 2) { // Followers
          label = 'Follow Back';
          bg = const Color(0xFF1D6FDC);
          fg = Colors.white;
        }

        return GestureDetector(
          onTap: () => PostStore.instance.toggleFollow(handle),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: border,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}
