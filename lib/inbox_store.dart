import 'dart:async';

import 'package:flutter/foundation.dart';

import 'post_model.dart';
import 'story_models.dart';

enum NotifType { like, comment, reply, save, follow, message, storyReact, tag, storyReply }

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
        NotifType.storyReply => '$actorName replied to your story',
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

/// A story attached to a chat message (the thumbnail shown above a story reply).
class StoryRef {
  final StoryData data;
  final String ownerName;
  final String ownerHandle;
  final DateTime time;

  /// True when the story belongs to me (someone replied to MY story).
  final bool mine;

  /// True when this message is a reaction (heart) instead of a typed reply.
  final bool reaction;

  const StoryRef({
    required this.data,
    required this.ownerName,
    required this.ownerHandle,
    required this.time,
    required this.mine,
    this.reaction = false,
  });
}

class ChatMessage {
  final String text;
  final bool fromMe;
  final DateTime time;
  final StoryRef? story;

  const ChatMessage({
    required this.text,
    required this.fromMe,
    required this.time,
    this.story,
  });

  /// Short line for the messages list.
  String get preview {
    final st = story;
    if (st == null) return text;
    if (st.reaction) return fromMe ? 'You reacted to their story' : 'Reacted to your story';
    return fromMe ? 'You replied to their story: $text' : 'Replied to your story: $text';
  }
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

  void send(String handle, String text, {StoryRef? story}) {
    _add(handle, ChatMessage(text: text, fromMe: true, time: DateTime.now(), story: story));
  }

  void receive(String handle, String text, {StoryRef? story}) {
    _add(handle, ChatMessage(text: text, fromMe: false, time: DateTime.now(), story: story));
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

/// A typed reply to my story.
class StoryReply {
  final String name;
  final String handle;
  final String text;
  final DateTime time;

  const StoryReply({
    required this.name,
    required this.handle,
    required this.text,
    required this.time,
  });
}

/// Someone else's story (what you see when you open their profile picture).
class OtherStory {
  final StoryData data;
  final DateTime time;
  const OtherStory({required this.data, required this.time});
}

/// The user's single active story, the reactions and replies it received,
/// and the stories of other people.
class StoryStore extends ChangeNotifier {
  StoryStore._();
  static final StoryStore instance = StoryStore._();

  StoryData data = StoryData();
  DateTime? postedAt;
  final List<StoryReaction> _reactions = [];
  final List<StoryReply> _replies = [];
  final Map<String, OtherStory> _others = {};
  final StreamController<StoryReaction> _reactionStream =
      StreamController<StoryReaction>.broadcast();

  /// Fires for every new reaction, so an open story can show animated hearts.
  Stream<StoryReaction> get onReaction => _reactionStream.stream;

  String get caption => data.caption;
  String? get imagePath => data.photoPath;
  int get bgColor => data.bgColor;

  /// A story lasts 24 hours, like a real story.
  bool get hasStory {
    if (!data.hasContent) return false;
    final p = postedAt;
    return p == null || DateTime.now().difference(p) < const Duration(hours: 24);
  }

  StoryData snapshot() => data.copy();

  /// Posts a new story (replaces the old one and its reactions and replies).
  void post(StoryData newData) {
    data = newData;
    postedAt = DateTime.now();
    _reactions.clear();
    _replies.clear();
    notifyListeners();
  }

  void delete() {
    data = StoryData();
    postedAt = null;
    _reactions.clear();
    _replies.clear();
    notifyListeners();
  }

  List<StoryReaction> get reactions => List.unmodifiable(_reactions);
  List<StoryReply> get replies => List.unmodifiable(_replies);

  void load({required String caption, required List<StoryReaction> reactions}) {
    data = StoryData(
      bgColor: 0xFF1D6FDC,
      layers: caption.isEmpty
          ? null
          : [StoryLayer(id: 'seed1', kind: StoryLayerKind.text, text: caption, dy: 0.5)],
    );
    _reactions
      ..clear()
      ..addAll(reactions);
    notifyListeners();
  }

  void react(String name, String handle, String emoji) {
    final r = StoryReaction(name: name, handle: handle, emoji: emoji, time: DateTime.now());
    _reactions.insert(0, r);
    notifyListeners();
    _reactionStream.add(r);
  }

  void addReply(String name, String handle, String text) {
    _replies.insert(
      0,
      StoryReply(name: name, handle: handle, text: text, time: DateTime.now()),
    );
    notifyListeners();
  }

  // ---- other people's stories ----

  OtherStory? otherStory(String handle) => _others[handle];

  void loadOthers(Map<String, OtherStory> stories) {
    _others
      ..clear()
      ..addAll(stories);
    notifyListeners();
  }
}
