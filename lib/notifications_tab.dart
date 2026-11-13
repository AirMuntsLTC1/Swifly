import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'count_badge.dart';
import 'inbox_store.dart';
import 'notification_router.dart';
import 'follow_button.dart';

const Color _brandBlue = Color(0xFF1D6FDC);
const Color _unreadTint = Color(0xFFE7F3FF);
const Color _grey = Color(0xFF65676B);

/// Lucide icon and badge colour for each notification type.
class _Style {
  final IconData icon;
  final Color color;
  const _Style(this.icon, this.color);
}

_Style _styleFor(NotifType t) => switch (t) {
      NotifType.like => _Style(LucideIcons.heart, const Color(0xFFE0245E)),
      NotifType.comment => _Style(LucideIcons.messageCircle, _brandBlue),
      NotifType.reply => _Style(LucideIcons.messageCircle, const Color(0xFF2E7D32)),
      NotifType.save => _Style(LucideIcons.bookmark, const Color(0xFFFF9800)),
      NotifType.follow => _Style(LucideIcons.userPlus, const Color(0xFF7C4DFF)),
      NotifType.message => _Style(LucideIcons.send, _brandBlue),
      NotifType.storyReact => _Style(LucideIcons.smile, const Color(0xFFE91E63)),
      NotifType.tag => _Style(LucideIcons.users, const Color(0xFF00897B)),
      NotifType.storyReply => _Style(LucideIcons.messageCircle, const Color(0xFF8E24AA)),
    };

/// Red unread count on the bell icon. Hidden when nothing is unread.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationStore.instance,
      builder: (context, _) => CountBadge(
        count: NotificationStore.instance.unreadCount,
        borderColor: Colors.white,
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationStore.instance,
      builder: (context, _) {
        final store = NotificationStore.instance;
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));

        // Unread items are "New". Read items are grouped by when they happened.
        final fresh = <AppNotification>[];
        final today = <AppNotification>[];
        final yest = <AppNotification>[];
        final earlier = <AppNotification>[];
        for (final n in store.items) {
          if (!n.read) {
            fresh.add(n);
          } else if (_sameDay(n.created, now)) {
            today.add(n);
          } else if (_sameDay(n.created, yesterday)) {
            yest.add(n);
          } else {
            earlier.add(n);
          }
        }
        final sections = <String, List<AppNotification>>{
          'New': fresh,
          'Today': today,
          'Yesterday': yest,
          'Earlier': earlier,
        };

        final children = <Widget>[];
        sections.forEach((title, items) {
          if (items.isEmpty) return;
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
          ));
          for (final n in items) {
            children.add(_NotificationRow(n: n));
          }
        });

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Notifications',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                  if (store.unreadCount > 0)
                    TextButton(
                      onPressed: () => store.markAllRead(),
                      child: const Text('Mark all read',
                          style: TextStyle(
                              color: _brandBlue, fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: children.isEmpty
                  ? const Center(
                      child: Text("You're all caught up",
                          style: TextStyle(color: _grey, fontSize: 15)))
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: children,
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

  /// Title without the name, so the name can be shown in bold.
  String get _body => n.title.startsWith(n.actorName)
      ? n.title.substring(n.actorName.length)
      : n.title;

  void _openMenu(BuildContext context) {
    final store = NotificationStore.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                n.read ? Icons.mark_email_unread_outlined : Icons.done,
                color: Colors.black,
              ),
              title: Text(n.read ? 'Mark as unread' : 'Mark as read',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                if (n.read) {
                  store.markUnread(n);
                } else {
                  store.markRead(n);
                }
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.black),
              title: const Text('Remove notification',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                store.remove(n);
                Navigator.pop(sheetContext);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: n.read ? Colors.white : _unreadTint,
      child: InkWell(
        onTap: () => NotificationRouter.open(n),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotifAvatar(type: n.type),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                            fontSize: 15, height: 1.3, color: Colors.black),
                        children: [
                          TextSpan(
                              text: n.actorName,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: _body),
                          TextSpan(
                              text: '  ${n.timeLabel}',
                              style: const TextStyle(fontSize: 13, color: _grey)),
                        ],
                      ),
                    ),
                    if (n.preview != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('"${n.preview}"',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: _grey)),
                      ),
                    if (n.type == NotifType.follow)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FollowButton(handle: n.actorHandle, compact: true),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz, color: _grey),
                onPressed: () => _openMenu(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile circle with a small coloured Lucide badge showing the notification type.
/// Used by the Notifications tab and by the popup banner, so both look the same.
class NotifAvatar extends StatelessWidget {
  final NotifType type;
  final double size;
  const NotifAvatar({super.key, required this.type, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(type);
    final badge = size * 0.43;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: Colors.black,
            child: Icon(LucideIcons.user, color: Colors.white, size: size * 0.46),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badge,
              height: badge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(style.icon, size: badge * 0.5, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
