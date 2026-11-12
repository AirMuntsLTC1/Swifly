import 'package:flutter/material.dart';

import 'inbox_store.dart';
import 'post_model.dart';
import 'story_player_screen.dart';
import 'story_viewer_screen.dart';
import 'story_widgets.dart';

class ChatScreen extends StatefulWidget {
  final String handle;
  const ChatScreen({super.key, required this.handle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ChatStore.instance.send(widget.handle, text);
    _controller.clear();
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

  Widget _storyCard(ChatMessage m) {
    final ref = m.story!;
    final label = ref.reaction
        ? (m.fromMe ? 'You reacted to their story' : 'Reacted to your story')
        : (m.fromMe ? 'You replied to their story' : 'Replied to your story');
    return Column(
      crossAxisAlignment: m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4, top: 6),
          child: Text(label,
              style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 12)),
        ),
        StoryThumb(data: ref.data, width: 96, onTap: () => _openStory(ref)),
      ],
    );
  }

  Widget _bubble(ChatMessage m) {
    final bubble = Align(
      alignment: m.fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: m.fromMe ? Colors.black : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          m.text,
          style: TextStyle(color: m.fromMe ? Colors.white : Colors.black, fontSize: 15),
        ),
      ),
    );
    if (m.story == null) return bubble;
    return Column(
      crossAxisAlignment: m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        _storyCard(m),
        const SizedBox(height: 2),
        bubble,
      ],
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
        iconTheme: const IconThemeData(color: Colors.black),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nameForHandle(widget.handle),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(widget.handle,
                style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: ChatStore.instance,
              builder: (context, _) {
                final msgs = ChatStore.instance.thread(widget.handle);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  children: [for (final m in msgs) _bubble(m)],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      cursorColor: Colors.black,
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        isDense: true,
                        filled: true,
                        fillColor: Color(0xFFF2F2F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}




