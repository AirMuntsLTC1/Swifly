import 'dart:async';

import 'package:flutter/material.dart';
import 'nav_guard.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'dm_people_screens.dart';
import 'dm_theme.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'media/preview_image.dart';
import 'post_detail_screen.dart';
import 'post_model.dart';
import 'story_player_screen.dart';
import 'story_viewer_screen.dart';
import 'story_widgets.dart';
import 'user_profile_screen.dart';
import 'people_directory.dart';

const List<String> _kReactionEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

class ChatScreen extends StatefulWidget {
  final String handle;
  const ChatScreen({super.key, required this.handle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  /// The message I am replying to (shown above the composer).
  ChatMessage? _replying;
  String? _flashId;
  Timer? _flashTimer;

  String get _handle => widget.handle;

  @override
  void initState() {
    super.initState();
    ChatStore.instance.openHandle = _handle;
    // Opening the chat marks it as read.
    WidgetsBinding.instance.addPostFrameCallback((_) => ChatStore.instance.markRead(_handle));
  }

  @override
  void dispose() {
    if (ChatStore.instance.openHandle == _handle) ChatStore.instance.openHandle = null;
    _flashTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- actions

  ReplyRef _refFor(ChatMessage m) => ReplyRef(
        messageId: m.id,
        text: m.text.trim().isEmpty ? (m.post?.title ?? m.text) : m.text,
        fromMe: m.fromMe,
        authorName: dmName(m.fromMe ? kMeHandle : _handle),
        authorHandle: m.fromMe ? kMeHandle : _handle,
      );

  void _startReply(ChatMessage m) {
    HapticFeedback.lightImpact();
    setState(() => _replying = m);
    _focus.requestFocus();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final reply = _replying;
    ChatStore.instance.send(_handle, text, replyTo: reply == null ? null : _refFor(reply));
    _controller.clear();
    setState(() => _replying = null);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _sendHeart() {
    ChatStore.instance.send(_handle, '❤️');
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _jumpTo(String messageId) {
    final ctx = _keys[messageId]?.currentContext;
    if (ctx == null) return; // the original is not in this chat (a note, or unsent)
    Scrollable.ensureVisible(ctx,
        alignment: 0.4, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    setState(() => _flashId = messageId);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _flashId = null);
    });
  }

  void _openStory(StoryRef ref) {
    if (ref.mine) {
      if (StoryStore.instance.hasStory) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StoryViewerScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This story is no longer available')),
        );
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryPlayerScreen(
          data: ref.data,
          name: ref.ownerName,
          handle: ref.ownerHandle,
          time: ref.time,
        ),
      ),
    );
  }

  void _openProfile() {
    pushOnce(context, UserProfileScreen.route(personFor(_handle)));
  }

  void _openTheirStory() {
    final s = StoryStore.instance.otherStory(_handle);
    if (s == null) {
      _openProfile();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryPlayerScreen(
            data: s.data, name: dmName(_handle), handle: _handle, time: s.time),
      ),
    );
  }

  // ------------------------------------------------------------- long press menu

  void _showActions(ChatMessage m) {
    HapticFeedback.mediumImpact();
    final c = DmTheme.instance.c;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0xB3000000),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, __) {
        void close() => Navigator.pop(dialogContext);
        Widget action(IconData icon, String label, VoidCallback onTap, {Color? color}) {
          return InkWell(
            onTap: () {
              close();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: TextStyle(color: color ?? c.text, fontSize: 16)),
                  ),
                  Icon(icon, color: color ?? c.text, size: 22),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Emoji reactions
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.sheet,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final e in _kReactionEmojis)
                            GestureDetector(
                              onTap: () {
                                close();
                                ChatStore.instance.react(_handle, m.id, e);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 7),
                                child: Text(e, style: const TextStyle(fontSize: 28)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // The message itself
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8),
                      child: _messageBody(m, c),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 230,
                      decoration: BoxDecoration(
                        color: c.sheet,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          action(Icons.reply_rounded, 'Reply', () => _startReply(m)),
                          action(Icons.copy_rounded, 'Copy', () {
                            Clipboard.setData(ClipboardData(
                                text: m.text.trim().isNotEmpty ? m.text : (m.post?.title ?? '')));
                          }),
                          if (m.fromMe)
                            action(Icons.undo_rounded, 'Unsend', () {
                              if (_replying?.id == m.id) setState(() => _replying = null);
                              ChatStore.instance.unsend(_handle, m.id);
                            }, color: Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- bubbles

  /// A shared post card (if any) followed by the typed text (if any).
  Widget _messageBody(ChatMessage m, DmColors c) {
    final post = m.post;
    if (post == null) return _bubbleBody(m, c);
    final hasText = m.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _postCard(post, c),
        if (hasText) ...[
          const SizedBox(height: 4),
          _bubbleBody(m, c),
        ],
      ],
    );
  }

  Widget _postCard(PostRef post, DmColors c) {
    final width = (MediaQuery.of(context).size.width * 0.62).clamp(190.0, 280.0).toDouble();
    final title = post.title.isEmpty ? 'Photo or video post' : post.title;
    return GestureDetector(
      onTap: () => pushOnce(context, postDetailRoute(post.postId)),
      child: Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.bubbleThem,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Row(
                children: [
                  DmAvatar(handle: post.authorHandle, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.text, fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
            if (post.thumbPath != null || post.mediaCount > 0)
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PreviewImage(
                      path: post.thumbPath,
                      cacheWidth: 600,
                      placeholderIcon:
                          post.isVideo ? LucideIcons.video : LucideIcons.image,
                    ),
                    if (post.isVideo)
                      const Center(
                        child: Icon(LucideIcons.play, color: Colors.white, size: 36),
                      ),
                    if (post.mediaCount > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('1/${post.mediaCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
              child: Text(title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.text, fontSize: 14, height: 1.3)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubbleBody(ChatMessage m, DmColors c) {
    final onlyEmoji = m.text.runes.length <= 2 && m.text.trim().isNotEmpty && m.text.runes.every((r) => r > 255);
    if (onlyEmoji && m.replyTo == null) {
      return Text(m.text, style: const TextStyle(fontSize: 44));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: m.fromMe ? kBubbleMe : null,
        color: m.fromMe ? null : c.bubbleThem,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        m.text,
        style: TextStyle(color: m.fromMe ? Colors.white : c.text, fontSize: 15.5),
      ),
    );
  }

  String _replyLabel(ChatMessage m) {
    final r = m.replyTo!;
    final first = dmName(_handle).split(' ').first;
    if (r.kind == ReplyKind.note) {
      if (m.fromMe) return r.fromMe ? 'You replied to your note' : 'You replied to their note';
      return r.fromMe ? 'Replied to your note' : 'Replied to their own note';
    }
    if (m.fromMe) return r.fromMe ? 'You replied to yourself' : 'You replied to $first';
    return r.fromMe ? '$first replied to you' : '$first replied to themself';
  }

  Widget _quote(ChatMessage m, DmColors c) {
    final r = m.replyTo!;
    final align = m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.reply_rounded, size: 14, color: c.sub),
              const SizedBox(width: 4),
              Text(_replyLabel(m), style: TextStyle(color: c.sub, fontSize: 12)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _jumpTo(r.messageId),
          child: Container(
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
            decoration: BoxDecoration(
              color: c.quoteBubble,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              r.quote,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.sub, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 3),
      ],
    );
  }

  Widget _storyCard(ChatMessage m, DmColors c) {
    final ref = m.story!;
    final label = ref.reaction
        ? (m.fromMe ? 'You reacted to their story' : 'Reacted to your story')
        : (m.fromMe ? 'You replied to their story' : 'Replied to your story');
    return Column(
      crossAxisAlignment: m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4, top: 6),
          child: Text(label, style: TextStyle(color: c.sub, fontSize: 12)),
        ),
        StoryThumb(data: ref.data, width: 96, onTap: () => _openStory(ref)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _message(ChatMessage m, DmColors c) {
    final align = m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final reaction = m.myReaction ?? m.theirReaction;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
      child: Column(
        crossAxisAlignment: align,
        children: [
          GestureDetector(
            onLongPress: () => _showActions(m),
            onDoubleTap: () => ChatStore.instance.react(_handle, m.id, '❤️'),
            child: _messageBody(m, c),
          ),
          if (reaction != null)
            Transform.translate(
              offset: Offset(m.fromMe ? -6 : 6, -8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.sheet,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.bg, width: 2),
                ),
                child: Text(reaction, style: const TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: align,
      children: [
        if (m.story != null) _storyCard(m, c),
        if (m.replyTo != null) _quote(m, c),
        bubble,
      ],
    );

    final flash = _flashId == m.id;
    return KeyedSubtree(
      key: _keys.putIfAbsent(m.id, () => GlobalKey()),
      child: _SwipeToReply(
        onReply: () => _startReply(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: flash ? c.chipFill : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Align(
            alignment: m.fromMe ? Alignment.centerRight : Alignment.centerLeft,
            child: content,
          ),
        ),
      ),
    );
  }

  String _stamp(DateTime t) {
    final now = DateTime.now();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    final clock = '$h:$mm $ap';
    if (t.year == now.year && t.month == now.month && t.day == now.day) return clock;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[t.month - 1]} ${t.day}, $clock';
  }

  Widget _timeHeader(DateTime t, DmColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(child: Text(_stamp(t), style: TextStyle(color: c.sub, fontSize: 12))),
      );

  // ------------------------------------------------------------- composer

  Widget _replyBar(DmColors c) {
    final m = _replying!;
    final who = m.fromMe ? kMeHandle : _handle;
    final title = m.fromMe ? 'Replying to yourself' : 'Replying to ${dmName(_handle)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          DmAvatar(handle: who, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: c.text, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(m.story != null || m.text.trim().isEmpty ? m.preview : m.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.sub, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.x, color: c.sub, size: 20),
            onPressed: () => setState(() => _replying = null),
          ),
        ],
      ),
    );
  }

  Widget _composer(DmColors c) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replying != null) _replyBar(c),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    cursorColor: c.text,
                    style: TextStyle(color: c.text, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(color: c.sub),
                      isDense: true,
                      filled: true,
                      fillColor: c.field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final has = value.text.trim().isNotEmpty;
                    return GestureDetector(
                      onTap: has ? _send : _sendHeart,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: has ? kBubbleMe : null,
                        ),
                        child: has
                            ? const Icon(Icons.send_rounded, color: Colors.white, size: 21)
                            : Icon(Icons.favorite_border_rounded, color: c.text, size: 26),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestBar(DmColors c) {
    final name = dmName(_handle);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Accept message request from $name?',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
                "If you accept, they can message you again and the chat moves to Primary. They won't be able to see when you're active until you accept.",
                textAlign: TextAlign.center,
                style: TextStyle(color: c.sub, fontSize: 12.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      ChatStore.instance.deleteThread(_handle);
                      Navigator.pop(context);
                    },
                    child: const Text('Delete',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => ChatStore.instance.accept(_handle),
                    child: Text('Accept',
                        style: TextStyle(
                            color: c.blue, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dmListenable(),
      builder: (context, _) {
        final c = DmTheme.instance.c;
        final store = ChatStore.instance;
        final msgs = store.thread(_handle).reversed.toList();
        final isRequest =
            store.hasThread(_handle) && store.bucketOf(_handle) == InboxTab.requests;
        final story = hasUnseenStory(_handle);
        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            backgroundColor: c.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 0,
            leading: IconButton(
              icon: Icon(LucideIcons.arrowLeft, color: c.text),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                GestureDetector(
                  onTap: _openTheirStory,
                  child: DmAvatar(handle: _handle, size: story ? 44 : 38, ring: story),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dmName(_handle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.text, fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(_handle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.sub, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (isRequest && !FollowStore.instance.isFollowing(_handle))
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(child: DmFollowButton(handle: _handle)),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: msgs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DmAvatar(handle: _handle, size: 84),
                            const SizedBox(height: 10),
                            Text(dmName(_handle),
                                style: TextStyle(
                                    color: c.text,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18)),
                            Text(_handle, style: TextStyle(color: c.sub)),
                            const SizedBox(height: 6),
                            Text('Say hi 👋', style: TextStyle(color: c.sub)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        itemCount: msgs.length,
                        itemBuilder: (context, i) {
                          final m = msgs[i];
                          final older = i + 1 < msgs.length ? msgs[i + 1] : null;
                          final showTime =
                              older == null || m.time.difference(older.time).inMinutes >= 60;
                          return Column(
                            children: [
                              if (showTime) _timeHeader(m.time, c),
                              _message(m, c),
                            ],
                          );
                        },
                      ),
              ),
              isRequest ? _requestBar(c) : _composer(c),
            ],
          ),
        );
      },
    );
  }
}

/// Drag a message to the right to reply (like Instagram).
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  const _SwipeToReply({required this.child, required this.onReply});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  static const double _trigger = 56;
  double _dx = 0;
  bool _dragging = false;
  bool _fired = false;

  @override
  Widget build(BuildContext context) {
    final c = DmTheme.instance.c;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => setState(() {
        _dragging = true;
        _fired = false;
      }),
      onHorizontalDragUpdate: (d) {
        final next = (_dx + d.delta.dx).clamp(0.0, 72.0).toDouble();
        if (!_fired && next >= _trigger) {
          _fired = true;
          HapticFeedback.selectionClick();
        }
        setState(() => _dx = next);
      },
      onHorizontalDragEnd: (_) {
        final fire = _fired;
        setState(() {
          _dragging = false;
          _dx = 0;
        });
        if (fire) widget.onReply();
      },
      onHorizontalDragCancel: () => setState(() {
        _dragging = false;
        _dx = 0;
      }),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Opacity(
            opacity: (_dx / _trigger).clamp(0.0, 1.0).toDouble(),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: c.chipFill, shape: BoxShape.circle),
              child: Icon(Icons.reply_rounded, size: 18, color: c.text),
            ),
          ),
          AnimatedContainer(
            duration: _dragging ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}



