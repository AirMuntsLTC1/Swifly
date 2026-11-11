import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'burst_icons.dart';
import 'native_bridge.dart';
import 'post_model.dart';

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
    return Row(
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
      ],
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
              child: Text(p.text,
                  style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black)),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    PostStore.instance.addComment(widget.postId, text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.7,
        child: ListenableBuilder(
          listenable: PostStore.instance,
          builder: (context, _) {
            final post = PostStore.instance.byId(widget.postId);
            final comments = post?.comments ?? const <CommentItem>[];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Comments (${comments.length})',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.black)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.x, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFEAEAEA)),
                Expanded(
                  child: comments.isEmpty
                      ? const Center(
                          child: Text('No comments yet',
                              style: TextStyle(color: Color(0xFF8E8E8E))),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: comments.length,
                          itemBuilder: (context, i) {
                            final c = comments[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.black,
                                    child: Icon(LucideIcons.user,
                                        color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: Colors.black)),
                                        const SizedBox(height: 2),
                                        Text(c.text,
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.black)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const Divider(height: 1, color: Color(0xFFEAEAEA)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          cursorColor: Colors.black,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Write a comment',
                            filled: true,
                            fillColor: Color(0xFFF2F2F2),
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(30)),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _send,
                        icon: const Icon(LucideIcons.send, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
