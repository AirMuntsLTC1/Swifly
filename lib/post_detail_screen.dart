import 'package:flutter/material.dart';
import 'hashtag_suggest.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'feed_widgets.dart';
import 'dm_theme.dart';
import 'nav_guard.dart';
import 'hashtag_text.dart';
import 'post_model.dart';
import 'typing_indicator.dart';

/// One post with its full comment thread. When [highlightId] is a comment or
/// reply id, that item scrolls into view and flashes. When it is null, the post
/// itself flashes.
class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String? highlightId;

  /// Flash the whole post when it opens. Used by notifications, not by the Comment button.
  final bool flashPost;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.highlightId,
    this.flashPost = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final HashtagAssist _hashtags = HashtagAssist(_controller);
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};
  late final AnimationController _flash;
  CommentItem? _replyingTo;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _highlight());
  }

  @override
  void dispose() {
    _flash.dispose();
    _hashtags.dispose();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  void _highlight() {
    if (!mounted) return;
    final id = widget.highlightId;
    if (id == null && !widget.flashPost) return;
    _flash.forward(from: 0);
    if (id == null) return;
    final ctx = _keys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
    }
  }

  /// Full strength for the first 30% of the flash, then fades to nothing.
  double get _intensity {
    final t = _flash.value;
    if (t < 0.3) return 1;
    return (1 - (t - 0.3) / 0.7).clamp(0.0, 1.0);
  }

  Widget _flashable({required bool active, required Widget child}) {
    if (!active) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) => ColoredBox(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.35 * _intensity),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _send(Post post) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final target = _replyingTo;
    if (target == null) {
      PostStore.instance.addComment(post.id, text);
    } else {
      PostStore.instance.addReply(post.id, target.id, text);
    }
    _controller.clear();
    setState(() => _replyingTo = null);
  }

  Widget _commentRow(CommentItem c, {required bool isReply}) {
    final r = isReply ? 13.0 : 16.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DmAvatar(
          handle: c.authorHandle,
          name: c.name,
          size: r * 2,
        ),
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
              HashtagText(c.text,
                  style: TextStyle(fontSize: isReply ? 13 : 14, color: Colors.black)),
              if (!isReply)
                GestureDetector(
                  onTap: () {
                    setState(() => _replyingTo = c);
                    _focus.requestFocus();
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
    );
  }

  Widget _commentsSection(Post post) {
    final total = post.totalComments;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comments · $total',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 14),
          if (post.comments.isEmpty)
            const Text('No comments yet. Be the first.',
                style: TextStyle(color: Color(0xFF8E8E8E))),
          for (final c in post.comments) ...[
            _flashable(
              active: widget.highlightId == c.id,
              child: KeyedSubtree(
                key: _keyFor(c.id),
                child: _commentRow(c, isReply: false),
              ),
            ),
            for (final r in c.replies)
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 12),
                child: _flashable(
                  active: widget.highlightId == r.id,
                  child: KeyedSubtree(
                    key: _keyFor(r.id),
                    child: _commentRow(r, isReply: true),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _composer(Post post) {
    final target = _replyingTo;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TypingIndicator(postId: post.id),
            if (target != null)
              Row(
                children: [
                  Expanded(
                    child: Text('Replying to ${target.name}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(LucideIcons.x, size: 16, color: Colors.black),
                  ),
                ],
              ),
            HashtagSuggestPanel(assist: _hashtags),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    cursorColor: Colors.black,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFFF2F2F2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.black),
                  onPressed: () => _send(post),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        title: const Text('Post',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: PostStore.instance,
        builder: (context, _) {
          final post = PostStore.instance.byId(widget.postId);
          if (post == null) {
            return const Center(
              child: Text('This post is no longer available.',
                  style: TextStyle(color: Color(0xFF8E8E8E))),
            );
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _flashable(
                        active: widget.highlightId == null && widget.flashPost,
                        child: PostCard(
                          post: post,
                          onComment: () => _focus.requestFocus(),
                        ),
                      ),
                      _commentsSection(post),
                    ],
                  ),
                ),
              ),
              _composer(post),
            ],
          );
        },
      ),
    );
  }
}

/// Opens the post page from the feed. The page slides in from the right with a
/// short fade, and slides back out the same way.
Route<void> postDetailRoute(String postId) => fastRoute<void>(
      name: 'post:$postId',
      child: PostDetailScreen(postId: postId),
    );
