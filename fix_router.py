content = r"""import 'dart:async';
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
      final postId = e.row['post_id'];
      DatabaseService.instance.personById('$senderId').then((who) async {
        PostRef? postRef;
        if (postId != null) {
          final p = await DatabaseService.instance.fetchPostById('$postId');
          if (p != null) {
            postRef = PostRef(
              postId: p['id'],
              authorName: p['author_name'],
              authorHandle: p['author_handle'],
              title: p['text'],
              thumbPath: p['thumb'],
              isVideo: p['is_video'],
              mediaCount: p['media_count'],
            );
          }
        }
        ChatStore.instance.receive(who['handle']!, '${e.row['text']}', post: postRef, story: null, replyTo: null);
      });
    } else if (e is ChatTypingEvent) {
      ChatTypingStore.instance.setTyping(e.handle, e.isTyping);
    }
  }
}
"""
import os
if not os.path.exists('lib'):
    raise SystemExit("Run this from the Swifly project root (no lib/ folder here).")
with open('lib/realtime_router.dart', 'w') as f:
    f.write(content)
print('Wrote lib/realtime_router.dart')
