import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_bootstrap.dart';
import 'database_service.dart';
import 'realtime.dart';
import 'supabase_config.dart';

/// Listens to the Supabase tables and turns every change made by OTHER people
/// into the app's RealtimeEvent (realtime.dart). The screens then update by
/// themselves, exactly as they did with the old simulated activity.
///
/// Things you do yourself are skipped here, because the screens already show
/// them instantly.
class SupabaseRealtime {
  static RealtimeChannel? _channel;
  static Timer? _postRefresh;

  static String? get _me =>
      kAuthEnabled ? Supabase.instance.client.auth.currentUser?.id : null;

  static void start() {
    final me = _me;
    if (me == null || _channel != null) return;

    _channel = Supabase.instance.client
        .channel('swifly-live-$me')
        // Likes and saves on posts
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'post_likes',
          callback: (p) => _onLike(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'post_saves',
          callback: (p) => _onSave(p.newRecord),
        )
        // Comments and replies
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          callback: (p) => _onComment(p.newRecord),
        )
        // Follows: someone followed me / unfollowed me
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'follows',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'followee',
            value: me,
          ),
          callback: (p) => _onFollow(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'follows',
          callback: (p) => _onUnfollow(p.oldRecord),
        )
        // Direct messages sent to me
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient',
            value: me,
          ),
          callback: (p) => _onMessage(p.newRecord),
        )
        // Tags: someone tagged me in a post
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: me,
          ),
          callback: (p) => _onNotification(p.newRecord),
        )
        // Notes (only notes of people I follow reach me)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notes',
          callback: (p) => _onNote(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notes',
          callback: (p) => _onNote(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notes',
          callback: (p) => _onNote(p.oldRecord, deleted: true),
        )
        // New posts from people I can see: reload the feed (after a short pause)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (p) => _onPost(p.newRecord),
        )
        .subscribe();
  }

  /// Stops listening. Called on log out.
  static Future<void> stop() async {
    _postRefresh?.cancel();
    _postRefresh = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await Supabase.instance.client.removeChannel(channel);
    }
  }

  static Future<void> _onLike(Map<String, dynamic> r) async {
    if ('${r['user_id']}' == _me) return;
    final who = await DatabaseService.instance.personById('${r['user_id']}');
    Realtime.instance.publish(PostLikedEvent(
      postId: '${r['post_id']}',
      actorName: who['name'] ?? '',
      actorHandle: who['handle'] ?? '',
    ));
  }

  static Future<void> _onSave(Map<String, dynamic> r) async {
    if ('${r['user_id']}' == _me) return;
    final who = await DatabaseService.instance.personById('${r['user_id']}');
    Realtime.instance.publish(PostSavedEvent(
      postId: '${r['post_id']}',
      actorName: who['name'] ?? '',
      actorHandle: who['handle'] ?? '',
    ));
  }

  static Future<void> _onComment(Map<String, dynamic> r) async {
    if ('${r['author_id']}' == _me) return;
    final who = await DatabaseService.instance.personById('${r['author_id']}');
    final parent = r['parent_id'];
    Realtime.instance.publish(CommentAddedEvent(
      postId: '${r['post_id']}',
      id: '${r['id']}',
      parentId: parent == null ? null : '$parent',
      actorName: who['name'] ?? '',
      actorHandle: who['handle'] ?? '',
      text: '${r['text']}',
    ));
  }

  static Future<void> _onFollow(Map<String, dynamic> r) async {
    if ('${r['follower']}' == _me) return;
    final who = await DatabaseService.instance.personById('${r['follower']}');
    Realtime.instance.publish(FollowedEvent(
      actorName: who['name'] ?? '',
      actorHandle: who['handle'] ?? '',
    ));
  }

  static Future<void> _onUnfollow(Map<String, dynamic> r) async {
    if ('${r['followee']}' != _me) return;
    final who = await DatabaseService.instance.personById('${r['follower']}');
    Realtime.instance.publish(UnfollowedEvent(
      actorName: who['name'] ?? '',
      actorHandle: who['handle'] ?? '',
    ));
  }

  static Future<void> _onMessage(Map<String, dynamic> r) async {
    final sender = '${r['sender']}';
    if (sender == _me) return;
    final who = await DatabaseService.instance.personById(sender);
    final replyId = r['reply_to_id'] == null ? null : '${r['reply_to_id']}';
    final replyText = replyId == null ? null : await DatabaseService.instance.messageText(replyId);
    Realtime.instance.publish(MessageEvent(
      actorName: who['name'] ?? '',
      actorHandle: who['handle'] ?? '',
      text: '${r['text']}',
      replyToId: replyId,
      replyToText: replyText,
    ));
  }

  /// Only tags come through here. Likes, comments, follows and messages are
  /// already handled by their own tables above.
  static Future<void> _onNotification(Map<String, dynamic> r) async {
    if ('${r['type']}' != 'tag') return;
    Realtime.instance.publish(TagEvent(
      postId: '${r['post_id']}',
      actorName: '${r['actor_name']}',
      actorHandle: '${r['actor_handle']}',
    ));
  }

  static Future<void> _onNote(Map<String, dynamic> r, {bool deleted = false}) async {
    final userId = '${r['user_id']}';
    if (userId == _me) return;
    final who = await DatabaseService.instance.personById(userId);
    Realtime.instance.publish(NoteEvent(
      actorName: who['name'] ?? '',
      actorHandle: who['handle'] ?? '',
      text: deleted ? '' : '${r['text']}',
    ));
  }

  /// A new post from someone else. Wait a moment in case several arrive together.
  static void _onPost(Map<String, dynamic> r) {
    if ('${r['author_id']}' == _me) return;
    _postRefresh?.cancel();
    _postRefresh = Timer(const Duration(milliseconds: 800), () {
      refreshPosts().catchError((_) {});
    });
  }
}
