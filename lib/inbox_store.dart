import 'dart:async';

import 'package:flutter/foundation.dart';

import 'post_model.dart';

enum NotifType { like, comment, reply, save, follow, message, storyReact }

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
        NotifType.reply => '$actorName replied to your comment',
        NotifType.save => '$actorName saved your post',
        NotifType.follow => '$actorName started following you',
        NotifType.message => '$actorName sent you a message',
        NotifType.storyReact => '$actorName reacted ' + (emoji ?? '') + ' to your story',
      };

  String get timeLabel => timeAgoLabel(created);
}

/// All notifications, newest first. Every new one is also pushed on [onNew],
/// which drives the popup banner.
class NotificationStore extends ChangeNotifier {
  NotificationStore._() {
    _seed();
  }

  static final NotificationStore instance = NotificationStore._();

  final List<AppNotification> _items = [];
  final StreamController<AppNotification> _incoming =
      StreamController<AppNotification>.broadcast();
  int _seq = 0;

  Stream<AppNotification> get onNew => _incoming.stream;
  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;

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

  void markAllRead() {
    for (final n in _items) {
      n.read = true;
    }
    notifyListeners();
  }

  void _seed() {
    final now = DateTime.now();
    _items.addAll([
      AppNotification(
        id: 'n${++_seq}',
        type: NotifType.like,
        actorName: 'Ava Stone',
        actorHandle: '@avastone',
        postId: kMyPostId,
        created: now.subtract(const Duration(minutes: 10)),
      ),
      AppNotification(
        id: 'n${++_seq}',
        type: NotifType.comment,
        actorName: 'Liam Park',
        actorHandle: '@liampark',
        postId: kMyPostId,
        commentId: 'demo-c1',
        preview: 'Welcome to Swifly!',
        created: now.subtract(const Duration(minutes: 30)),
      ),
      AppNotification(
        id: 'n${++_seq}',
        type: NotifType.follow,
        actorName: 'Mia Chen',
        actorHandle: '@miachen',
        created: now.subtract(const Duration(hours: 1)),
      ),
      AppNotification(
        id: 'n${++_seq}',
        type: NotifType.message,
        actorName: 'Ava Stone',
        actorHandle: '@avastone',
        preview: 'See you at the hike!',
        created: now.subtract(const Duration(hours: 2)),
        read: true,
      ),
      AppNotification(
        id: 'n${++_seq}',
        type: NotifType.storyReact,
        actorName: 'Noah Reed',
        actorHandle: '@noahreed',
        emoji: '🔥',
        created: now.subtract(const Duration(hours: 3)),
        read: true,
      ),
    ]);
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
  ChatStore._() {
    _seed();
  }

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

  void _seed() {
    final now = DateTime.now();
    _threads['@avastone'] = [
      ChatMessage(
          text: 'Did you see the sunrise pics?',
          fromMe: false,
          time: now.subtract(const Duration(days: 1))),
      ChatMessage(
          text: 'See you at the hike!',
          fromMe: false,
          time: now.subtract(const Duration(hours: 2))),
    ];
    _threads['@liampark'] = [
      ChatMessage(
          text: 'Check out my new build',
          fromMe: false,
          time: now.subtract(const Duration(hours: 8))),
    ];
    _threads['@miachen'] = [
      ChatMessage(
          text: 'Coffee on Saturday?',
          fromMe: false,
          time: now.subtract(const Duration(days: 1))),
    ];
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

  final String caption = 'My weekend so far';
  final List<StoryReaction> _reactions = [
    StoryReaction(
      name: 'Noah Reed',
      handle: '@noahreed',
      emoji: '🔥',
      time: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  List<StoryReaction> get reactions => List.unmodifiable(_reactions);

  void react(String name, String handle, String emoji) {
    _reactions.insert(
      0,
      StoryReaction(name: name, handle: handle, emoji: emoji, time: DateTime.now()),
    );
    notifyListeners();
  }
}

/// Simulates other people's activity so the notification flow can be tested
/// without a server. Each step changes the real stores and then notifies.
/// Set [demo] to false once a backend delivers these events instead.
class LiveEvents {
  static const bool demo = true;
  static const Duration interval = Duration(seconds: 15);

  static Timer? _timer;
  static int _step = 0;

  static void start() {
    if (!demo || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => _runNext());
  }

  static void _runNext() {
    final steps = <void Function()>[
      _like,
      _comment,
      _reply,
      _save,
      _follow,
      _message,
      _storyReact,
    ];
    steps[_step % steps.length]();
    _step++;
  }

  static void _like() {
    if (!PostStore.instance.receiveLike(kMyPostId)) return;
    NotificationStore.instance.add(
      type: NotifType.like,
      actorName: 'Ava Stone',
      actorHandle: '@avastone',
      postId: kMyPostId,
    );
  }

  static void _comment() {
    const text = 'Congrats on the new post!';
    final cid = PostStore.instance.receiveComment(kMyPostId, 'Liam Park', text);
    if (cid == null) return;
    NotificationStore.instance.add(
      type: NotifType.comment,
      actorName: 'Liam Park',
      actorHandle: '@liampark',
      postId: kMyPostId,
      commentId: cid,
      preview: text,
    );
  }

  static void _reply() {
    const text = 'Thanks Liam, appreciate it!';
    final rid = PostStore.instance
        .receiveReply(kMyPostId, 'demo-c1', 'Noah Reed', text);
    if (rid == null) return;
    NotificationStore.instance.add(
      type: NotifType.reply,
      actorName: 'Noah Reed',
      actorHandle: '@noahreed',
      postId: kMyPostId,
      commentId: rid,
      preview: text,
    );
  }

  static void _save() {
    if (!PostStore.instance.receiveSave(kMyPostId)) return;
    NotificationStore.instance.add(
      type: NotifType.save,
      actorName: 'Mia Chen',
      actorHandle: '@miachen',
      postId: kMyPostId,
    );
  }

  static void _follow() {
    PostStore.instance.receiveFollower('@omarkh');
    NotificationStore.instance.add(
      type: NotifType.follow,
      actorName: 'Omar Khalid',
      actorHandle: '@omarkh',
    );
  }

  static void _message() {
    const text = 'Are we still on for Saturday?';
    ChatStore.instance.receive('@sofial', text);
    NotificationStore.instance.add(
      type: NotifType.message,
      actorName: 'Sofia Lopez',
      actorHandle: '@sofial',
      preview: text,
    );
  }

  static void _storyReact() {
    StoryStore.instance.react('Max Turner', '@maxturner', '❤️');
    NotificationStore.instance.add(
      type: NotifType.storyReact,
      actorName: 'Max Turner',
      actorHandle: '@maxturner',
      emoji: '❤️',
    );
  }
}
