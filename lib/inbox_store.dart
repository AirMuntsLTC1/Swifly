import 'dart:async';

import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'follow_store.dart';
import 'native_bridge.dart';
import 'post_model.dart';
import 'story_models.dart';

enum NotifType { like, comment, reply, save, follow, message, storyReact, tag, storyReply }

/// Short relative time label such as "now", "5m", "3h", "2d".
String timeAgoLabel(DateTime created) {
  if (NativeCore.isNativeReady) return NativeCore.dmTimeLabel(created);
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

/// What kind of thing a reply points at.
enum ReplyKind { message, note }

/// The message (or note) that a chat message is replying to.
class ReplyRef {
  final String messageId;
  final String text;
  final bool fromMe;
  final String authorName;
  final String authorHandle;
  final ReplyKind kind;

  const ReplyRef({
    required this.messageId,
    required this.text,
    required this.fromMe,
    required this.authorName,
    required this.authorHandle,
    this.kind = ReplyKind.message,
  });

  /// Quoted text, cut short by the C++ core.
  String get quote => NativeCore.dmClip(text, 90);
}

int _msgSeq = 0;

class ChatMessage {
  final String id;
  final String text;
  final bool fromMe;
  final DateTime time;
  final StoryRef? story;

  /// Set when this message is a reply to another message or to a note.
  final ReplyRef? replyTo;

  /// Emoji I reacted with, and the emoji they reacted with.
  String? myReaction;
  String? theirReaction;

  ChatMessage({
    String? id,
    required this.text,
    required this.fromMe,
    required this.time,
    this.story,
    this.replyTo,
    this.myReaction,
    this.theirReaction,
  }) : id = id ?? 'm${++_msgSeq}';

  /// Short line for the messages list (clipped by the C++ core).
  String get preview {
    final st = story;
    if (st != null) {
      if (st.reaction) {
        return fromMe ? 'You reacted to their story' : 'Reacted to your story';
      }
      final t = NativeCore.dmClip(text, 60);
      return fromMe ? 'You replied to their story: $t' : 'Replied to your story: $t';
    }
    final t = NativeCore.dmClip(text, 70);
    return fromMe ? 'You: $t' : t;
  }
}

/// Which inbox tab a conversation is in.
enum InboxTab { primary, requests, general }

/// Filter flags (must match swifly_dm_filter_pass in C++).
const int kFlagUnread = 1;
const int kFlagUnanswered = 2;
const int kFlagStoryReply = 4;
const int kFlagFollowing = 8;
const int kFlagFollowsMe = 16;

/// Direct message threads keyed by the other person's handle.
///
/// This is the ONLY place chat state lives. To connect the real database:
///   1. Call [load] with the threads you fetch.
///   2. [send] already calls DatabaseService.sendMessage (replace its body).
///   3. Realtime "new message" events call [receive].
class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  final Map<String, List<ChatMessage>> _threads = {};
  final Map<String, int> _unread = {};
  final Set<String> _accepted = {};

  /// The chat that is open on screen right now (new messages there are read).
  String? openHandle;

  DateTime _lastTime(String handle) => _threads[handle]!.last.time;

  /// Every handle with a conversation, newest message first (sorted in C++).
  List<String> get handles {
    final list = _threads.keys.toList();
    final order = NativeCore.dmSortThreads(
        [for (final h in list) _lastTime(h).millisecondsSinceEpoch]);
    return [for (final i in order) list[i]];
  }

  List<ChatMessage> thread(String handle) =>
      List.unmodifiable(_threads[handle] ?? const <ChatMessage>[]);

  bool hasThread(String handle) => (_threads[handle] ?? const []).isNotEmpty;

  ChatMessage? last(String handle) {
    final t = _threads[handle];
    return (t == null || t.isEmpty) ? null : t.last;
  }

  // ---- unread ----

  int unread(String handle) => _unread[handle] ?? 0;

  /// Number of conversations with something unread (shown as the red badge).
  /// Message requests are not counted, like on Instagram.
  int get unreadThreads => _threads.keys
      .where((h) => unread(h) > 0 && bucketOf(h) != InboxTab.requests)
      .length;

  int get requestCount =>
      _threads.keys.where((h) => bucketOf(h) == InboxTab.requests).length;

  int get unreadRequestCount => _threads.keys
      .where((h) => bucketOf(h) == InboxTab.requests && unread(h) > 0)
      .length;

  void markRead(String handle) {
    if ((_unread[handle] ?? 0) == 0) return;
    _unread[handle] = 0;
    notifyListeners();
  }

  void markUnread(String handle) {
    if (!_threads.containsKey(handle)) return;
    _unread[handle] = 1;
    notifyListeners();
  }

  // ---- requests ----

  bool iReplied(String handle) =>
      (_threads[handle] ?? const <ChatMessage>[]).any((m) => m.fromMe);

  InboxTab bucketOf(String handle) {
    final last = _lastTime(handle);
    final n = NativeCore.dmBucket(
      isFollowing: FollowStore.instance.isFollowing(handle),
      iReplied: iReplied(handle),
      accepted: _accepted.contains(handle),
      hoursSinceLast: DateTime.now().difference(last).inHours,
      unread: unread(handle),
    );
    return InboxTab.values[n.clamp(0, 2)];
  }

  /// A request becomes a normal chat.
  void accept(String handle) {
    _accepted.add(handle);
    notifyListeners();
  }

  /// Removes the whole conversation.
  void deleteThread(String handle) {
    _threads.remove(handle);
    _unread.remove(handle);
    _accepted.remove(handle);
    notifyListeners();
  }

  // ---- filters ----

  int flagsOf(String handle) {
    final t = _threads[handle] ?? const <ChatMessage>[];
    var f = 0;
    if (unread(handle) > 0) f |= kFlagUnread;
    if (t.isNotEmpty && !t.last.fromMe) f |= kFlagUnanswered;
    if (t.any((m) => m.story != null)) f |= kFlagStoryReply;
    if (FollowStore.instance.isFollowing(handle)) f |= kFlagFollowing;
    if (FollowStore.instance.isFollower(handle)) f |= kFlagFollowsMe;
    return f;
  }

  // ---- loading and sending ----

  void load(Map<String, List<ChatMessage>> threads) {
    _threads
      ..clear()
      ..addAll(threads.map((k, v) => MapEntry(k, List<ChatMessage>.of(v))));
    _unread.clear();
    _accepted.clear();
    // Everything they sent after my last message starts as unread.
    for (final e in _threads.entries) {
      var n = 0;
      for (var i = e.value.length - 1; i >= 0 && !e.value[i].fromMe; i--) {
        n++;
      }
      if (n > 0) _unread[e.key] = n;
    }
    notifyListeners();
  }

  void send(String handle, String text, {StoryRef? story, ReplyRef? replyTo}) {
    _add(
      handle,
      ChatMessage(text: text, fromMe: true, time: DateTime.now(), story: story, replyTo: replyTo),
    );
    DatabaseService.instance.sendMessage(handle, text, replyToId: replyTo?.messageId);
  }

  void receive(String handle, String text, {StoryRef? story, ReplyRef? replyTo}) {
    final m = ChatMessage(
        text: text, fromMe: false, time: DateTime.now(), story: story, replyTo: replyTo);
    _add(handle, m);
    if (openHandle == handle) return;
    _unread[handle] = (_unread[handle] ?? 0) + 1;
    notifyListeners();
  }

  /// Removes one of MY messages for both people.
  void unsend(String handle, String messageId) {
    final t = _threads[handle];
    if (t == null) return;
    t.removeWhere((m) => m.id == messageId && m.fromMe);
    if (t.isEmpty) {
      _threads.remove(handle);
      _unread.remove(handle);
    }
    notifyListeners();
  }

  /// Sets (or clears, when [emoji] is null or the same) my reaction on a message.
  void react(String handle, String messageId, String? emoji) {
    final t = _threads[handle];
    if (t == null) return;
    for (final m in t) {
      if (m.id == messageId) {
        m.myReaction = (m.myReaction == emoji) ? null : emoji;
        break;
      }
    }
    notifyListeners();
  }

  void _add(String handle, ChatMessage m) {
    _threads.putIfAbsent(handle, () => <ChatMessage>[]).add(m);
    notifyListeners();
  }
}

/// A short note (up to 60 characters) shown above the inbox for 24 hours.
class DmNote {
  final String handle;
  final String text;
  final DateTime time;
  const DmNote({required this.handle, required this.text, required this.time});

  bool get expired => DateTime.now().difference(time) >= const Duration(hours: 24);
}

class NoteStore extends ChangeNotifier {
  NoteStore._();
  static final NoteStore instance = NoteStore._();

  DmNote? _mine;
  final Map<String, DmNote> _others = {};

  DmNote? get mine => (_mine == null || _mine!.expired) ? null : _mine;

  DmNote? noteOf(String handle) {
    final n = _others[handle];
    return (n == null || n.expired) ? null : n;
  }

  /// Handles that currently have a note, newest first.
  List<String> get handlesWithNotes {
    final list = _others.entries.where((e) => !e.value.expired).toList()
      ..sort((a, b) => b.value.time.compareTo(a.value.time));
    return [for (final e in list) e.key];
  }

  void setMine(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _mine = DmNote(handle: kMeHandle, text: t, time: DateTime.now());
    notifyListeners();
    DatabaseService.instance.saveNote(t);
  }

  void deleteMine() {
    _mine = null;
    notifyListeners();
    DatabaseService.instance.saveNote('');
  }

  void load(Map<String, DmNote> others) {
    _others
      ..clear()
      ..addAll(others);
    notifyListeners();
  }

  /// Someone posted a new note (from realtime).
  void applyIncoming(String handle, String text) {
    _others[handle] = DmNote(handle: handle, text: text, time: DateTime.now());
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

  OtherStory? otherStory(String handle) {
    final o = _others[handle];
    if (o == null) return null;
    return DateTime.now().difference(o.time) < const Duration(hours: 24) ? o : null;
  }

  /// Handles of people who currently have a story.
  List<String> get otherHandles =>
      [for (final h in _others.keys) if (otherStory(h) != null) h];

  void loadOthers(Map<String, OtherStory> stories) {
    _others
      ..clear()
      ..addAll(stories);
    notifyListeners();
  }
}
