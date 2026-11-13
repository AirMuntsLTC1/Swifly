import 'dart:async';

/// Every change from other people arrives as one of these events.
/// Mock data and the real database both publish into [Realtime]; the screens never
/// need to know where an event came from.
sealed class RealtimeEvent {
  const RealtimeEvent();
}

class PostLikedEvent extends RealtimeEvent {
  final String postId;
  final String actorName;
  final String actorHandle;
  const PostLikedEvent({required this.postId, required this.actorName, required this.actorHandle});
}

class PostSavedEvent extends RealtimeEvent {
  final String postId;
  final String actorName;
  final String actorHandle;
  const PostSavedEvent({required this.postId, required this.actorName, required this.actorHandle});
}

/// A top-level comment when [parentId] is null, otherwise a reply.
class CommentAddedEvent extends RealtimeEvent {
  final String postId;
  final String id;
  final String? parentId;
  final String actorName;
  final String actorHandle;
  final String text;
  const CommentAddedEvent({
    required this.postId,
    required this.id,
    required this.actorName,
    required this.actorHandle,
    required this.text,
    this.parentId,
  });
}

class TypingEvent extends RealtimeEvent {
  final String postId;
  final String actorName;
  final String actorHandle;
  final bool isTyping;
  const TypingEvent({
    required this.postId,
    required this.actorName,
    required this.actorHandle,
    required this.isTyping,
  });
}

class TagEvent extends RealtimeEvent {
  final String postId;
  final String actorName;
  final String actorHandle;
  const TagEvent({required this.postId, required this.actorName, required this.actorHandle});
}

class FollowedEvent extends RealtimeEvent {
  final String actorName;
  final String actorHandle;
  const FollowedEvent({required this.actorName, required this.actorHandle});
}

class MessageEvent extends RealtimeEvent {
  final String actorName;
  final String actorHandle;
  final String text;

  /// Set when this message is a reply to one of MY messages in that chat.
  final String? replyToId;
  final String? replyToText;
  const MessageEvent({
    required this.actorName,
    required this.actorHandle,
    required this.text,
    this.replyToId,
    this.replyToText,
  });
}

/// Someone shared or changed their note.
class NoteEvent extends RealtimeEvent {
  final String actorName;
  final String actorHandle;
  final String text;
  const NoteEvent({required this.actorName, required this.actorHandle, required this.text});
}

class StoryReactionEvent extends RealtimeEvent {
  final String actorName;
  final String actorHandle;
  final String emoji;
  const StoryReactionEvent({required this.actorName, required this.actorHandle, required this.emoji});
}

/// Single inbound stream. The mock driver and, later, the Supabase listener call [publish].
class Realtime {
  Realtime._();
  static final Realtime instance = Realtime._();

  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get stream => _controller.stream;

  void publish(RealtimeEvent event) => _controller.add(event);
}

/// Someone typed a reply to my story.
class StoryReplyEvent extends RealtimeEvent {
  final String actorName;
  final String actorHandle;
  final String text;
  const StoryReplyEvent({required this.actorName, required this.actorHandle, required this.text});
}

class UnfollowedEvent extends RealtimeEvent {
  final String actorName;
  final String actorHandle;
  const UnfollowedEvent({required this.actorName, required this.actorHandle});
}



