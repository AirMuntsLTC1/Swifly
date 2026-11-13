import 'dart:async';
import 'inbox_store.dart';
import 'post_model.dart';
import 'realtime.dart';
import 'database_service.dart';

class RealtimeRouter {
  static StreamSubscription<RealtimeEvent>? _sub;

  static void init() {
    _sub ??= Realtime.instance.stream.listen(_apply);
  }

  static void _apply(RealtimeEvent e) {
    if (e is PostChangedEvent) {
      final p = PostStore.instance.byId(e.postId);
      if (p != null) {
        p.likes = e.likes;
        p.saves = e.saves;
        p.shares = e.shares;
        PostStore.instance.notifyListeners();
      }
    } else if (e is NotificationAddedEvent) {
      NotificationStore.instance.insertFromRow(e.row);
    } else if (e is MessageReceivedEvent) {
      final senderId = e.row['sender'];
      // Simplified: router relies on ChatStore to fetch peer handle
      DatabaseService.instance.personById('$senderId').then((who) {
        ChatStore.instance.receive(who['handle']!, '${e.row['text']}', post: null, story: null, replyTo: null);
      });
    } else if (e is ChatTypingEvent) {
      ChatTypingStore.instance.setTyping(e.handle, e.isTyping);
    }
  }
}
