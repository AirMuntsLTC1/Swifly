import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'chat_screen.dart';
import 'inbox_store.dart';
import 'post_model.dart';

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ChatStore.instance,
      builder: (context, _) {
        final handles = ChatStore.instance.handles;
        if (handles.isEmpty) {
          return const Center(
            child: Text('No messages yet', style: TextStyle(color: Color(0xFF8E8E8E))),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: handles.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEAEAEA)),
          itemBuilder: (context, i) {
            final h = handles[i];
            final last = ChatStore.instance.thread(h).last;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const CircleAvatar(
                backgroundColor: Colors.black,
                child: Icon(LucideIcons.user, color: Colors.white, size: 20),
              ),
              title: Text(nameForHandle(h),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
              subtitle: Text(last.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF6E6E6E))),
              trailing: Text(timeAgoLabel(last.time),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(handle: h)),
              ),
            );
          },
        );
      },
    );
  }
}
