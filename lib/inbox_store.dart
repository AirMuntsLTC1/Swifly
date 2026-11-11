import 'dart:async';

import 'package:flutter/foundation.dart';

import 'post_model.dart';

enum NotifType { like, comment, reply, save, follow, message, storyReact, tag }

/// Short relative time label such as "now", "5m", "3h", "2d".
String timeAgoLabel(DateTime created) {
  final d = DateTime.now().difference(created);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}

class AppNotification {
  final String id;
  final NotifType type;
  final String actorName;
  final String actorHandle;
  final DateTime created;
  final String? postId;
  final String? commentId;
  final String? emoji;
  final String? preview;
  bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.actorName,
    required this.actorHandle,
    required this.created,
    this.postId,
    this.commentId,
    this.emoji,
    this.preview,
    this.read = false,
  });

  String get title => switch (type) {
        NotifType.like => '$actorName liked your post',
        NotifType.comment => '$actorName commented on your post',
        NotifType.reply => '$actorName replied to a comment',
        NotifType.save => '$actorName saved your post',
        NotifType.follow => '$actorName started following you',
        NotifType.message => '$actorName sent you a message',
        NotifType.storyReact => '$actorName reacted ${emoji ?? ""} to your story',
        NotifType.tag => '$actorName tagged you in a post',
      };

  String get timeLabel => timeAgoLabel(created);
}

/// All notifications, newest first. Each new one is also pushed on [onNew],
/// which drives the popup banner.
class NotificationStore extends ChangeNotifier {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  final List<AppNotification> _items = [];
  final StreamController<AppNotification> _incoming =
      StreamController<AppNotification>.broadcast();
  int _seq = 0;

  Stream<AppNotification> get onNew => _incoming.stream;
  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;

  /// Replaces the list with saved notifications. Does not show banners.
  void load(List<AppNotification> saved) {
    _items
      ..clear()
      ..addAll(saved);
    notifyListeners();
  }

  void add({
    required NotifType type,
    required String actorName,
    required String actorHandle,
    String? postId,
    String? commentId,
    String? emoji,
    String? preview,
  }) {
    final n = AppNotification(
      id: 'n${++_seq}',
      type: type,
      actorName: actorName,
      actorHandle: actorHandle,
      created: DateTime.now(),
      postId: postId,
      commentId: commentId,
      emoji: emoji,
      preview: preview,
    );
    _items.insert(0, n);
    notifyListeners();
    _incoming.add(n);
  }

  void markRead(AppNotification n) {
    if (n.read) return;
    n.read = true;
    notifyListeners();
  }

  void markUnread(AppNotification n) {
    if (!n.read) return;
    n.read = false;
    notifyListeners();
  }

  void remove(AppNotification n) {
    _items.remove(n);
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _items) {
      n.read = true;
    }
    notifyListeners();
  }
}

class ChatMessage {
  final String text;
  final bool fromMe;
  final DateTime time;

  const ChatMessage({required this.text, required this.fromMe, required this.time});
}

/// Direct message threads keyed by the other person's handle.
class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  final Map<String, List<ChatMessage>> _threads = {};

  /// Handles with a conversation, most recent message first.
  List<String> get handles {
    final list = _threads.keys.toList();
    list.sort((a, b) => _lastTime(b).compareTo(_lastTime(a)));
    return list;
  }

  DateTime _lastTime(String handle) => _threads[handle]!.last.time;

  List<ChatMessage> thread(String handle) =>
      List.unmodifiable(_threads[handle] ?? const <ChatMessage>[]);

  void load(Map<String, List<ChatMessage>> threads) {
    _threads
      ..clear()
      ..addAll(threads.map((k, v) => MapEntry(k, List<ChatMessage>.of(v))));
    notifyListeners();
  }

  void send(String handle, String text) {
    _add(handle, ChatMessage(text: text, fromMe: true, time: DateTime.now()));
  }

  void receive(String handle, String text) {
    _add(handle, ChatMessage(text: text, fromMe: false, time: DateTime.now()));
  }

  void _add(String handle, ChatMessage m) {
    _threads.putIfAbsent(handle, () => <ChatMessage>[]).add(m);
    notifyListeners();
  }
}

class StoryReaction {
  final String name;
  final String handle;
  final String emoji;
  final DateTime time;

  const StoryReaction({
    required this.name,
    required this.handle,
    required this.emoji,
    required this.time,
  });
}

/// The user's single active story and the reactions it has received.
class StoryStore extends ChangeNotifier {
  StoryStore._();
  static final StoryStore instance = StoryStore._();

  String caption = '';
  final List<StoryReaction> _reactions = [];

  List<StoryReaction> get reactions => List.unmodifiable(_reactions);

  void load({required String caption, required List<StoryReaction> reactions}) {
    this.caption = caption;
    _reactions
      ..clear()
      ..addAll(reactions);
    notifyListeners();
  }

  void react(String name, String handle, String emoji) {
    _reactions.insert(
      0,
      StoryReaction(name: name, handle: handle, emoji: emoji, time: DateTime.now()),
    );
    notifyListeners();
  }
}
