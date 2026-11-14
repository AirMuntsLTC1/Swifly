import 'dart:async';

import 'package:flutter/material.dart';

import 'inbox_store.dart';
import 'notification_router.dart';
import 'notifications_tab.dart';

/// Shows a popup card at the top of the screen whenever a notification arrives.
/// Tap it to open the target, or swipe it up to dismiss.
class NotificationBanner {
  static StreamSubscription<AppNotification>? _sub;

  static void init() {
    _sub ??= NotificationStore.instance.onNew.listen(_show);
  }

  static void _show(AppNotification n) {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        child: _BannerCard(
          notification: n,
          onDone: () => entry.remove(),
        ),
      ),
    );
    overlay.insert(entry);
  }
}

class _BannerCard extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDone;

  const _BannerCard({required this.notification, required this.onDone});

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _timer = Timer(const Duration(seconds: 4), () => _finish(open: false));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool open}) async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    final n = widget.notification;
    await _controller.reverse();
    widget.onDone();
    if (open) NotificationRouter.open(n);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(curve),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () => _finish(open: true),
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -200) _finish(open: false);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  NotifAvatar(type: n.type, handle: n.actorHandle, size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black),
                        ),
                        if (n.preview != null)
                          Text(
                            n.preview!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6E6E6E)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
