import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'inbox_store.dart';
import 'story_models.dart';
import 'story_widgets.dart';

/// Watching someone else's story: progress bar, animated heart reactions
/// (double tap or the heart button) and a reply box. A reply or reaction goes
/// to that person's Messages with a thumbnail of the story above it.
class StoryPlayerScreen extends StatefulWidget {
  final StoryData data;
  final String name;
  final String handle;
  final DateTime time;

  const StoryPlayerScreen({
    super.key,
    required this.data,
    required this.name,
    required this.handle,
    required this.time,
  });

  @override
  State<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends State<StoryPlayerScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _quick = ['❤️', '😂', '😮', '😢', '🔥', '👏'];

  late final AnimationController _progress;
  final FocusNode _focus = FocusNode();
  final TextEditingController _reply = TextEditingController();
  final GlobalKey<HeartBurstLayerState> _hearts = GlobalKey<HeartBurstLayerState>();
  final Set<String> _reacted = {};
  bool _held = false;
  bool _heartDown = false;
  Offset _lastDoubleTap = Offset.zero;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: const Duration(seconds: 7))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) Navigator.pop(context);
      })
      ..forward();
    _focus.addListener(_syncPause);
  }

  @override
  void dispose() {
    _progress.dispose();
    _focus.removeListener(_syncPause);
    _focus.dispose();
    _reply.dispose();
    super.dispose();
  }

  void _syncPause() {
    if (!mounted) return;
    if (_held || _focus.hasFocus) {
      _progress.stop();
    } else if (_progress.status != AnimationStatus.completed) {
      _progress.forward();
    }
    setState(() {});
  }

  StoryRef _ref({bool reaction = false}) => StoryRef(
        data: widget.data,
        ownerName: widget.name,
        ownerHandle: widget.handle,
        time: widget.time,
        mine: false,
        reaction: reaction,
      );

  void _react(String emoji) {
    _hearts.currentState?.burst(emoji: emoji, count: emoji == '❤️' ? 14 : 10);
    setState(() => _heartDown = true);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _heartDown = false);
    });
    // One message per emoji, so double-tapping does not spam the chat.
    if (_reacted.add(emoji)) {
      ChatStore.instance.send(widget.handle, 'Reacted $emoji to their story',
          story: _ref(reaction: true));
    }
  }

  void _sendReply() {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    ChatStore.instance.send(widget.handle, text, story: _ref());
    _reply.clear();
    _focus.unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Reply sent to ${widget.name}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    _syncPause();
  }

  Widget _header() {
    final place = widget.data.place;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.black,
            child: Icon(LucideIcons.user, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    Text(timeAgoLabel(widget.time),
                        style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
                if (place != null)
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 12, color: Colors.white70),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    final hasText = _reply.text.trim().isNotEmpty;
    final first = widget.name.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _reply,
              focusNode: _focus,
              minLines: 1,
              maxLines: 3,
              cursorColor: Colors.white,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _sendReply(),
              decoration: InputDecoration(
                hintText: 'Reply to $first...',
                hintStyle: const TextStyle(color: Colors.white60),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: Colors.white54, width: 1.4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: Colors.white, width: 1.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (hasText)
            IconButton(
              tooltip: 'Send',
              onPressed: _sendReply,
              icon: const Icon(LucideIcons.send, color: Colors.white, size: 26),
            )
          else
            AnimatedScale(
              scale: _heartDown ? 1.4 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              child: IconButton(
                tooltip: 'Heart',
                onPressed: () => _react('❤️'),
                icon: _reacted.contains('❤️')
                    ? const Text('❤️', style: TextStyle(fontSize: 26))
                    : const Icon(LucideIcons.heart, color: Colors.white, size: 28),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _progress.value,
                    minHeight: 3,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
            _header(),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: kStoryW / kStoryH,
                  child: LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTapDown: (d) => _lastDoubleTap = d.localPosition,
                      onDoubleTap: () {
                        final p = _lastDoubleTap;
                        _hearts.currentState?.pop(
                          x: (p.dx / box.maxWidth).clamp(0.1, 0.9),
                          y: (p.dy / box.maxHeight).clamp(0.1, 0.9),
                        );
                        _react('❤️');
                      },
                      onLongPressStart: (_) {
                        _held = true;
                        _syncPause();
                      },
                      onLongPressEnd: (_) {
                        _held = false;
                        _syncPause();
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          StoryCanvas(data: widget.data, radius: 18),
                          HeartBurstLayer(key: _hearts),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_focus.hasFocus)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final e in _quick)
                      GestureDetector(
                        onTap: () => _react(e),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(e, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                  ],
                ),
              ),
            _composer(),
          ],
        ),
      ),
    );
  }
}



