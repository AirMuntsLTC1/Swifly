import 'dart:async';

sealed class RealtimeEvent {
  const RealtimeEvent();
}

class PostChangedEvent extends RealtimeEvent {
  final String postId;
  final int likes;
  final int saves;
  final int shares;
  const PostChangedEvent({required this.postId, required this.likes, required this.saves, required this.shares});
}

class NotificationAddedEvent extends RealtimeEvent {
  final Map<String, dynamic> row;
  const NotificationAddedEvent(this.row);
}

class MessageReceivedEvent extends RealtimeEvent {
  final Map<String, dynamic> row;
  const MessageReceivedEvent(this.row);
}

class ChatTypingEvent extends RealtimeEvent {
  final String handle;
  final bool isTyping;
  const ChatTypingEvent({required this.handle, required this.isTyping});
}

class Realtime {
  Realtime._();
  static final Realtime instance = Realtime._();
  final StreamController<RealtimeEvent> _controller = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get stream => _controller.stream;
  void publish(RealtimeEvent event) => _controller.add(event);
}
