import 'package:flutter/material.dart';

import 'inbox_store.dart';
import 'notification_router.dart';

IconData iconForNotif(NotifType type) => switch (type) {
      NotifType.like => Icons.favorite,
      NotifType.comment => Icons.chat_bubble,
      NotifType.reply => Icons.reply,
      NotifType.save => Icons.bookmark,
      NotifType.follow => Icons.person_add,
      NotifType.message => Icons.send,
      NotifType.storyReact => Icons.emoji_emotions,
    };

/// Red unread counter shown on the bell icon. Hidden when nothing is unread.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationStore.instance,
      builder: (context, _) {
        final count = NotificationStore.instance.unreadCount;
        if (count == 0) return const SizedBox.shrink();
        return IgnorePointer(
          child: Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              count > 9 ? '9+' : '$count',
              style: const TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        );
      },
    );
  }
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationStore.instance,
      builder: (context, _) {
        final store = NotificationStore.instance;
        final items = store.items;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(
                children: [
                  const Text('Notifications',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black)),
                  const Spacer(),
                  if (store.unreadCount > 0)
                    TextButton(
                      onPressed: () => store.markAllRead(),
                      child: const Text('Mark all read',
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAEAEA)),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('No notifications yet',
                          style: TextStyle(color: Color(0xFF8E8E8E))))
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFEAEAEA)),
                      itemBuilder: (context, i) => _NotificationRow(n: items[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification n;
  const _NotificationRow({required this.n});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => NotificationRouter.open(n),
      child: Container(
        color: n.read ? Colors.white : const Color(0xFFF5F8FF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.black,
              child: Icon(iconForNotif(n.type), color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                      fontWeight: n.read ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                  if (n.preview != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${n.preview}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6E6E6E)),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(n.timeLabel,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
                ],
              ),
            ),
            if (!n.read)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF1D6FDC),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
