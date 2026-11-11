import 'dart:async';

import 'inbox_store.dart';
import 'post_model.dart';
import 'realtime.dart';
import 'typing_store.dart';

/// Applies every realtime event to the stores and creates the matching notification.
/// Each screen listens to the stores, so changes show up everywhere at once.
class RealtimeRouter {
  static StreamSubscription<RealtimeEvent>? _sub;

  static void init() {
    _sub ??= Realtime.instance.stream.listen(_apply);
  }

  static bool _onMyPost(String postId) =>
      PostStore.instance.byId(postId)?.authorHandle == kMeHandle;

  static void _apply(RealtimeEvent e) {
    final posts = PostStore.instance;
    final notes = NotificationStore.instance;

    if (e is PostLikedEvent) {
      if (!posts.receiveLike(e.postId)) return;
      if (_onMyPost(e.postId)) {
        notes.add(
          type: NotifType.like,
          actorName: e.actorName,
          actorHandle: e.actorHandle,
          postId: e.postId,
        );
      }
    } else if (e is PostSavedEvent) {
      if (!posts.receiveSave(e.postId)) return;
      if (_onMyPost(e.postId)) {
        notes.add(
          type: NotifType.save,
          actorName: e.actorName,
          actorHandle: e.actorHandle,
          postId: e.postId,
        );
      }
    } else if (e is CommentAddedEvent) {
      final added = posts.applyComment(
        postId: e.postId,
        id: e.id,
        name: e.actorName,
        text: e.text,
        parentId: e.parentId,
      );
      // A finished comment means that person has stopped typing.
      TypingStore.instance.setTyping(e.postId, e.actorHandle, e.actorName, false);
      if (!added || !_onMyPost(e.postId)) return;
      notes.add(
        type: e.parentId == null ? NotifType.comment : NotifType.reply,
        actorName: e.actorName,
        actorHandle: e.actorHandle,
        postId: e.postId,
        commentId: e.id,
        preview: e.text,
      );
    } else if (e is TypingEvent) {
      TypingStore.instance.setTyping(e.postId, e.actorHandle, e.actorName, e.isTyping);
    } else if (e is FollowedEvent) {
      posts.receiveFollower(e.actorHandle);
      notes.add(
        type: NotifType.follow,
        actorName: e.actorName,
        actorHandle: e.actorHandle,
      );
    } else if (e is MessageEvent) {
      ChatStore.instance.receive(e.actorHandle, e.text);
      notes.add(
        type: NotifType.message,
        actorName: e.actorName,
        actorHandle: e.actorHandle,
        preview: e.text,
      );
    } else if (e is StoryReactionEvent) {
      StoryStore.instance.react(e.actorName, e.actorHandle, e.emoji);
      notes.add(
        type: NotifType.storyReact,
        actorName: e.actorName,
        actorHandle: e.actorHandle,
        emoji: e.emoji,
      );
    }
  }
}
