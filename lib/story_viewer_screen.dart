import 'database_service.dart';
import 'app_feedback.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'chat_screen.dart';
import 'inbox_store.dart';
import 'story_models.dart';
import 'story_widgets.dart';

/// Shows my own story exactly as people see it, with live animated hearts when
/// someone reacts, plus everyone who reacted or replied. [highlightHandle]
/// marks the person who opened this screen from a notification.
class StoryViewerScreen extends StatefulWidget {
  final String? highlightHandle;
  const StoryViewerScreen({super.key, this.highlightHandle});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  final GlobalKey<HeartBurstLayerState> _hearts = GlobalKey<HeartBurstLayerState>();
  StreamSubscription<StoryReaction>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = StoryStore.instance.onReaction.listen((r) {
      _hearts.currentState?.burst(emoji: r.emoji, count: 14, x: 0.5, y: 0.95);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Widget _row(BuildContext context, {
    required Widget leading,
    required String name,
    String? text,
    required DateTime time,
    required String handle,
    bool isReply = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isReply
          ? () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => ChatScreen(handle: handle)))
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: handle == widget.highlightHandle
              ? const Color(0xFF3A3A3A)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(width: 30, child: Center(child: leading)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  if (text != null)
                    Text(text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            Text(timeAgoLabel(time),
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Your story',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Delete story',
            icon: const Icon(LucideIcons.trash2),
            onPressed: () {
              final storyId = StoryStore.instance.storyId;
              StoryStore.instance.delete();
              if (storyId != null) {
                DatabaseService.instance
                    .deleteStory(storyId)
                    .catchError((Object e) => reportError('Story not deleted', e));
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: StoryStore.instance,
        builder: (context, _) {
          final store = StoryStore.instance;
          final items = <({DateTime time, Widget child})>[
            for (final r in store.replies)
              (
                time: r.time,
                child: _row(
                  context,
                  leading: const Icon(LucideIcons.messageCircle,
                      color: Colors.white, size: 22),
                  name: r.name,
                  text: r.text,
                  time: r.time,
                  handle: r.handle,
                  isReply: true,
                ),
              ),
            for (final r in store.reactions)
              (
                time: r.time,
                child: _row(
                  context,
                  leading: Text(r.emoji, style: const TextStyle(fontSize: 22)),
                  name: r.name,
                  time: r.time,
                  handle: r.handle,
                ),
              ),
          ]..sort((a, b) => b.time.compareTo(a.time));
          final place = store.data.place;
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AspectRatio(
                      aspectRatio: kStoryW / kStoryH,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          StoryCanvas(data: store.data, radius: 18),
                          HeartBurstLayer(key: _hearts),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${store.reactions.length} reactions · ${store.replies.length} replies'
                      '${place == null ? '' : ' · $place'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.22,
                      child: items.isEmpty
                          ? const Center(
                              child: Text('No reactions or replies yet',
                                  style: TextStyle(color: Colors.white38)),
                            )
                          : ListView(children: [for (final i in items) i.child]),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}



