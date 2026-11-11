import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'inbox_store.dart';
import 'post_detail_screen.dart';
import 'story_viewer_screen.dart';
import 'tag_friends_screen.dart';
import 'user_profile_screen.dart';

/// Used by the popup banner and the notifications list to navigate from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class NotificationRouter {
  static void open(AppNotification n) {
    NotificationStore.instance.markRead(n);
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    switch (n.type) {
      case NotifType.like:
      case NotifType.save:
      case NotifType.comment:
      case NotifType.reply:
        nav.push(MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            postId: n.postId ?? '',
            highlightId: n.commentId,
          ),
        ));
        break;
      case NotifType.follow:
        nav.push(UserProfileScreen.route(Friend(n.actorName, n.actorHandle)));
        break;
      case NotifType.message:
        nav.push(MaterialPageRoute(builder: (_) => ChatScreen(handle: n.actorHandle)));
        break;
      case NotifType.storyReact:
        nav.push(MaterialPageRoute(
          builder: (_) => StoryViewerScreen(highlightHandle: n.actorHandle),
        ));
        break;
      case NotifType.tag:
        nav.push(MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: n.postId ?? ''),
        ));
        break;
    }
  }
}
