import os
import shutil
import zipfile

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True) if os.path.dirname(path) else None
    with open(path, 'w') as f:
        f.write(content)
    print(f"✅ Updated: {path}")

print("Applying Ultimate Architecture & Sync Fixes...\n")

# ==========================================
# 1. NEW FILE: STARTUP TIMER
# ==========================================
write_file("lib/startup_timer.dart", """import 'package:flutter/foundation.dart';

class StartupTimer {
  static final DateTime _start = DateTime.now();
  static void log(String step) {
    final elapsed = DateTime.now().difference(_start).inMilliseconds;
    debugPrint('[Swifly startup] $step (${elapsed}ms)');
  }
}
""")

# ==========================================
# 2. REALTIME EVENTS (realtime.dart)
# ==========================================
write_file("lib/realtime.dart", """import 'dart:async';

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
""")

# ==========================================
# 3. POST MODEL (Pagination, Per-User Cache, Merge)
# ==========================================
write_file("lib/post_model.dart", """import 'app_feedback.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'media/media_item.dart';
import 'native_bridge.dart';
import 'database_service.dart';
import 'db_mappers.dart';
import 'people_directory.dart';

String nameForHandle(String handle) {
  for (final f in kPeople) {
    if (f.handle == handle) return f.name;
  }
  return handle;
}

int _commentSeq = 0;

class CommentItem {
  String id;
  final String name;
  final String text;
  final DateTime created;
  final List<CommentItem> replies;

  CommentItem({
    required this.name,
    required this.text,
    required this.created,
    String? id,
    List<CommentItem>? replies,
  })  : id = id ?? 'c${++_commentSeq}',
        replies = replies ?? <CommentItem>[];

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'text': text, 'created': created.toIso8601String(),
    'replies': replies.map((r) => r.toJson()).toList(),
  };

  factory CommentItem.fromJson(Map<String, dynamic> json) => CommentItem(
    id: json['id'], name: json['name'], text: json['text'],
    created: DateTime.parse(json['created']),
    replies: (json['replies'] as List? ?? []).map((r) => CommentItem.fromJson(r)).toList(),
  );
}

class Post {
  String id;
  final String authorName;
  final String authorHandle;
  final String text;
  final String audience;
  final List<String> taggedHandles;
  final List<MediaItem> media;
  final DateTime created;
  final List<CommentItem> comments;
  int likes;
  bool liked;
  int saves;
  bool saved;
  int shares;

  Post({
    required this.id, required this.authorName, required this.authorHandle,
    required this.text, required this.audience, required this.created,
    this.taggedHandles = const [], this.media = const [],
    this.likes = 0, this.liked = false, this.saves = 0, this.saved = false, this.shares = 0,
    List<CommentItem>? comments,
  }) : comments = comments ?? <CommentItem>[];

  List<String> get hashtags => NativeCore.extractHashtags(text);
  bool hasHashtag(String tag) => NativeCore.countHashtag(text, tag) > 0;
  double get hoursOld => DateTime.now().difference(created).inSeconds / 3600.0;
  int get totalComments => comments.fold<int>(0, (n, c) => n + 1 + c.replies.length);

  String get timeLabel {
    final d = DateTime.now().difference(created);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'authorName': authorName, 'authorHandle': authorHandle,
    'text': text, 'audience': audience, 'taggedHandles': taggedHandles,
    'created': created.toIso8601String(), 'likes': likes, 'liked': liked,
    'saves': saves, 'saved': saved, 'shares': shares,
    'media': media.map((m) => m.toJson()).toList(),
    'comments': comments.map((c) => c.toJson()).toList(),
  };

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'], authorName: json['authorName'], authorHandle: json['authorHandle'],
    text: json['text'], audience: json['audience'],
    taggedHandles: List<String>.from(json['taggedHandles'] ?? []),
    created: DateTime.parse(json['created']),
    likes: json['likes'] ?? 0, liked: json['liked'] ?? false,
    saves: json['saves'] ?? 0, saved: json['saved'] ?? false, shares: json['shares'] ?? 0,
    media: (json['media'] as List? ?? []).map((m) => MediaItem.fromJson(m)).toList(),
    comments: (json['comments'] as List? ?? []).map((c) => CommentItem.fromJson(c)).toList(),
  );
}

class PostStore extends ChangeNotifier {
  PostStore._();
  static final PostStore instance = PostStore._();

  final List<Post> _posts = [];
  int _nextId = 1;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadMorePosts() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final saved = await DatabaseService.instance.fetchPosts(limit: 10, offset: _posts.length);
      if (saved.isNotEmpty) {
        for (final r in saved) {
          final p = postFromRow(r);
          if (!_posts.any((existing) => existing.id == p.id)) _posts.add(p);
        }
        notifyListeners();
        saveCache();
      }
    } catch (_) {}
    _isLoadingMore = false;
    notifyListeners();
  }

  void load({required List<Post> posts}) {
    _posts..clear()..addAll(posts);
    notifyListeners();
  }

  /// Merges new posts into existing ones without losing optimistic UI posts
  void merge({required List<Post> newPosts}) {
    final Map<String, Post> merged = {for (final p in _posts) p.id: p};
    for (final p in newPosts) {
      merged[p.id] = p;
    }
    _posts..clear()..addAll(merged.values.toList()..sort((a, b) => b.created.compareTo(a.created)));
    notifyListeners();
    saveCache();
  }

  List<Post> get ranked {
    final validPosts = _posts.where((p) => p.text.trim().isNotEmpty || p.media.isNotEmpty).toList();
    final mine = validPosts.where((p) => p.authorHandle == kMeHandle).toList()..sort((a, b) => b.created.compareTo(a.created));
    final others = validPosts.where((p) => p.authorHandle != kMeHandle).toList();
    final order = NativeCore.rankOrder(
      others.map((p) => p.likes).toList(), others.map((p) => p.totalComments).toList(),
      others.map((p) => p.saves).toList(), others.map((p) => p.hoursOld).toList(),
    );
    return [...mine, for (final i in order) others[i]];
  }

  int countFor(String handle) => _posts.where((p) => p.authorHandle == handle).length;
  List<Post> get unsaved => _posts.where((p) => !DatabaseService.isUuid(p.id)).toList();
  List<Post> get myPosts => _posts.where((p) => p.authorHandle == kMeHandle).toList()..sort((a, b) => b.created.compareTo(a.created));
  void mediaUpdated() => notifyListeners();

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    final safeHandle = kMeHandle.replaceAll('@', '').trim();
    return File('${dir.path}/feed_cache_$safeHandle.json');
  }

  Future<void> saveCache() async {
    try {
      final file = await _cacheFile();
      final data = _posts.take(20).map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> loadCache() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as List;
        if (_posts.isEmpty) {
          _posts.addAll(data.map((item) => Post.fromJson(item)));
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> clearCache() async {
    _posts.clear();
    notifyListeners();
    try {
      final file = await _cacheFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Post? byId(String id) { for (final p in _posts) { if (p.id == id) return p; } return null; }

  // Optimistic updates
  Future<void> addPost({required String text, required String audience, required List<String> taggedHandles, List<MediaItem> media = const []}) async {
    final newPost = Post(id: 'p${_nextId++}', authorName: kMeName, authorHandle: kMeHandle, text: text, audience: audience, taggedHandles: List.of(taggedHandles), media: media, created: DateTime.now());
    _posts.insert(0, newPost);
    notifyListeners();
    try {
      final serverId = await DatabaseService.instance.savePost(text, audience, taggedHandles, media);
      if (serverId != null) newPost.id = serverId;
      saveCache();
    } catch (e) {
      reportError('Post not saved', e);
      _posts.removeWhere((p) => p.id == newPost.id);
      notifyListeners();
    }
  }

  Future<void> toggleLike(String id) async {
    final p = byId(id); if (p == null) return;
    p.liked = !p.liked; p.likes += p.liked ? 1 : -1; notifyListeners();
    try { await DatabaseService.instance.toggleLike(id, p.liked); }
    catch (e) { p.liked = !p.liked; p.likes += p.liked ? 1 : -1; notifyListeners(); }
  }
}
""")

# ==========================================
# 4. INBOX STORE (Read state, typing expiry, notification sync)
# ==========================================
inbox = open("lib/inbox_store.dart").read()
# Add methods to ChatStore for read state
inbox = inbox.replace(
    "  String? openHandle;",
    "  String? openHandle;\n  final Set<String> _readThreads = {};\n\n  void markRead(String handle) {\n    _unread[handle] = 0;\n    _readThreads.add(handle);\n    notifyListeners();\n  }\n\n  bool isThreadRead(String handle) => _readThreads.contains(handle) || (_unread[handle] ?? 0) == 0;\n\n  void reset() {\n    _threads.clear(); _unread.clear(); _readThreads.clear(); _accepted.clear(); notifyListeners();\n  }"
)
# Remove old markRead
inbox = inbox.replace(
    "  void markRead(String handle) {\n    if ((_unread[handle] ?? 0) == 0) return;\n    _unread[handle] = 0;\n    notifyListeners();\n  }",
    ""
)
# Typing store expiry
inbox = inbox.replace(
    "class ChatTypingStore extends ChangeNotifier {\n  ChatTypingStore._();\n  static final ChatTypingStore instance = ChatTypingStore._();\n  final Set<String> _typingHandles = {};\n\n  bool isTyping(String handle) => _typingHandles.contains(handle);\n\n  void setTyping(String handle, bool typing) {\n    if (typing) {\n      if (_typingHandles.add(handle)) notifyListeners();\n    } else {\n      if (_typingHandles.remove(handle)) notifyListeners();\n    }\n  }\n}",
    """class ChatTypingStore extends ChangeNotifier {
  ChatTypingStore._();
  static final ChatTypingStore instance = ChatTypingStore._();
  final Set<String> _typingHandles = {};
  final Map<String, Timer> _timers = {};

  bool isTyping(String handle) => _typingHandles.contains(handle);

  void setTyping(String handle, bool typing) {
    _timers[handle]?.cancel();
    if (typing) {
      if (_typingHandles.add(handle)) notifyListeners();
      _timers[handle] = Timer(const Duration(seconds: 6), () => setTyping(handle, false));
    } else {
      if (_typingHandles.remove(handle)) notifyListeners();
    }
  }
}"""
)
write_file("lib/inbox_store.dart", inbox)

# ==========================================
# 5. DATABASE SERVICE (Fix fetchNotifications, handle lookup, cache clearing)
# ==========================================
db = open("lib/database_service.dart").read()
db = db.replace(
    """  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final rows = await _db
        .from('notifications')
        .select('*')
        .eq('user_id', _requireMe())
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }""",
    """  Future<List<Map<String, dynamic>>> fetchNotifications({int limit = 50, int offset = 0}) async {
    final rows = await _db
        .from('notifications')
        .select('*')
        .eq('user_id', _requireMe())
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }"""
)
# Add clearLocalMediaCache
db = db.replace(
    "// ---------------------------------------------------------------------------\n  // helpers",
    """  Future<void> clearLocalMediaCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final mediaDir = Directory('${dir.path}/media_cache');
      if (await mediaDir.exists()) await mediaDir.delete(recursive: true);
      final files = dir.listSync();
      for (final f in files) {
        if (f.path.contains('feed_cache_') && f.path.endsWith('.json')) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // helpers"""
)
write_file("lib/database_service.dart", db)

# ==========================================
# 6. SUPABASE REALTIME (Reconnect, Broadcast typing, DB notifications)
# ==========================================
write_file("lib/supabase_realtime.dart", """import 'app_feedback.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_bootstrap.dart';
import 'database_service.dart';
import 'realtime.dart';
import 'supabase_config.dart';

class SupabaseRealtime with WidgetsBindingObserver {
  static final SupabaseRealtime instance = SupabaseRealtime._();
  SupabaseRealtime._();

  RealtimeChannel? _channel;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  bool _isConnected = false;

  String? get _me => kAuthEnabled ? Supabase.instance.client.auth.currentUser?.id : null;

  void initLifecycle() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isConnected) {
      _connect();
    }
  }

  static void start() {
    instance._connect();
  }

  void _connect() {
    final me = _me;
    if (me == null || _isConnected) return;

    _channel?.unsubscribe();
    _channel = Supabase.instance.client.channel('swifly-live-$me');

    _channel!
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'posts',
        callback: (p) => _onPostUpdate(p.newRecord),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        callback: (p) => _onNotification(p.newRecord),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(column: 'recipient', value: me, type: PostgresChangeFilterType.eq),
        callback: (p) => _onMessage(p.newRecord),
      )
      .onBroadcast(
        event: 'chat_typing',
        callback: (payload) {
          final handle = payload['handle'] as String?;
          final isTyping = payload['isTyping'] as bool? ?? false;
          if (handle != null && handle != '@$me') {
            Realtime.instance.publish(ChatTypingEvent(handle: handle, isTyping: isTyping));
          }
        },
      );

    _channel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isConnected = true;
        _retryCount = 0;
        _reconnectTimer?.cancel();
      } else if (status == RealtimeSubscribeStatus.closed || status == RealtimeSubscribeStatus.channelError) {
        _isConnected = false;
        _scheduleReconnect();
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 << _retryCount).clamp(2, 60));
    _retryCount++;
    _reconnectTimer = Timer(delay, _connect);
  }

  static void sendTyping(String handle, bool isTyping) {
    final channel = instance._channel;
    if (channel != null && instance._isConnected) {
      channel.sendBroadcastMessage(
        event: 'chat_typing',
        payload: {'handle': handle, 'isTyping': isTyping},
      );
    }
  }

  static Future<void> stop() async {
    instance._reconnectTimer?.cancel();
    instance._isConnected = false;
    await instance._channel?.unsubscribe();
    instance._channel = null;
  }

  void _onPostUpdate(Map<String, dynamic> r) {
    Realtime.instance.publish(PostChangedEvent(
      postId: '${r['id']}', likes: r['likes'] ?? 0, saves: r['saves'] ?? 0, shares: r['shares'] ?? 0,
    ));
  }

  void _onNotification(Map<String, dynamic> r) {
    if ('${r['user_id']}' == _me) {
      Realtime.instance.publish(NotificationAddedEvent(r));
    }
  }

  void _onMessage(Map<String, dynamic> r) {
    if ('${r['sender']}' != _me) {
      Realtime.instance.publish(MessageReceivedEvent(r));
    }
  }
}
""")

# ==========================================
# 7. REALTIME ROUTER (Apply events directly)
# ==========================================
write_file("lib/realtime_router.dart", """import 'dart:async';
import 'inbox_store.dart';
import 'post_model.dart';
import 'realtime.dart';

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
""")

# ==========================================
# 8. APP BOOTSTRAP (Queued loads)
# ==========================================
write_file("lib/app_bootstrap.dart", """import 'app_feedback.dart';
import 'database_service.dart';
import 'db_mappers.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'people_directory.dart';
import 'post_model.dart';
import 'profile_store.dart';
import 'supabase_config.dart';
import 'supabase_realtime.dart';
import 'startup_timer.dart';

bool _loading = false;
bool _pendingReload = false;

Future<void> loadAppData() async {
  if (!kAuthEnabled) return;
  if (_loading) { _pendingReload = true; return; }
  _loading = true;
  StartupTimer.log('loadAppData started');

  try {
    await _loadFromDatabase();
  } finally {
    _loading = false;
    StartupTimer.log('loadAppData finished');
    if (_pendingReload) {
      _pendingReload = false;
      loadAppData();
    }
  }
}

void startLiveActivity() {
  if (!kAuthEnabled) return;
  SupabaseRealtime.start();
}

Future<void> _loadFromDatabase() async {
  final db = DatabaseService.instance;
  await Future.wait([
    db.fetchMe().then((me) { if (me != null) { CurrentUser.name = me['name'] ?? me['display_name']; CurrentUser.handle = me['handle']; } }).catchError((_) {}),
    db.fetchPeople().then((rows) => PeopleDirectory.instance.load(people: rows.map(personFromRow).toList(), stats: statsFromRows(rows))).catchError((_) {}),
    db.fetchPosts(limit: 20, offset: 0).then((rows) => PostStore.instance.merge(newPosts: rows.map(postFromRow).toList())).catchError((_) {}),
    db.fetchFollows().then((f) => FollowStore.instance.load(following: (f['following'] ?? []).toSet(), followers: (f['followers'] ?? []).toSet())).catchError((_) {}),
    db.fetchNotifications().then((rows) => NotificationStore.instance.load(rows.map(notificationFromRow).toList())).catchError((_) {}),
    db.fetchMessages().then((rows) => ChatStore.instance.load(threadsFromRows(rows))).catchError((_) {}),
    ProfileStore.instance.loadFromDatabase().catchError((_) {}),
  ]);
}

Future<void> clearAppData() async {
  try { await SupabaseRealtime.stop(); } catch (_) {}
  CurrentUser.name = 'Your Name'; CurrentUser.handle = '@yourhandle';
  PeopleDirectory.instance.load();
  PostStore.instance.load(posts: []);
  await PostStore.instance.clearCache();
  FollowStore.instance.load();
  NotificationStore.instance.load([]);
  ChatStore.instance.reset();
  await ProfileStore.instance.clearDevice();
  await DatabaseService.instance.clearLocalMediaCache();
}
""")

# ==========================================
# 9. SPLASH SCREEN (Instant cache, background load)
# ==========================================
write_file("lib/splash_screen.dart", """import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'auth/auth_flow.dart';
import 'app_bootstrap.dart';
import 'auth_service.dart';
import 'post_model.dart';
import 'startup_timer.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  String _status = 'Connecting to Swifly...';

  @override
  void initState() {
    super.initState();
    StartupTimer.log('Splash screen mounted');
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await AuthService.init().timeout(const Duration(seconds: 10));
      if (!AuthService.instance.needsLogin) {
        AuthService.instance.applyUser();
        setState(() => _status = 'Loading your feed...');
        await PostStore.instance.loadCache(); // Load offline cache instantly
        
        // Load network data in the background
        loadAppData();
        startLiveActivity();
      }
    } catch (e) {
      debugPrint('Init Error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, animation, secondaryAnimation) => startScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 112, height: 112,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30)),
                child: const Icon(LucideIcons.flaskConical, color: Colors.white, size: 56),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Swifly', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 48),
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black)),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
          ],
        ),
      ),
    );
  }
}
""")

# ==========================================
# 10. MAIN.DART (Lifecycle watcher)
# ==========================================
write_file("lib/main.dart", """import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'app_feedback.dart';
import 'media/media_pipeline.dart';
import 'logo_service.dart';
import 'notification_banner.dart';
import 'notification_router.dart';
import 'profile_store.dart';
import 'realtime_router.dart';
import 'supabase_realtime.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 120);
  
  ProfileStore.instance.loadFromDevice();
  LogoService.instance.load();
  RealtimeRouter.init();
  NotificationBanner.init();
  SupabaseRealtime.instance.initLifecycle();
  
  runApp(const SocialApp());
  MediaPipeline.instance.ensureReady().then((_) => MediaPipeline.instance.trimCache());
}

class SocialApp extends StatelessWidget {
  const SocialApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifly', navigatorKey: appNavigatorKey, scaffoldMessengerKey: appMessengerKey,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.black, brightness: Brightness.light), scaffoldBackgroundColor: Colors.white),
      home: const SplashScreen(),
    );
  }
}
""")

# ==========================================
# 11. AUTH FLOW (Clear cache on logout)
# ==========================================
auth = open("lib/auth/auth_flow.dart").read()
auth = auth.replace(
    "await clearAppData();",
    "await clearAppData();\n  await PostStore.instance.clearCache();"
)
write_file("lib/auth/auth_flow.dart", auth)

# ==========================================
# 12. CHAT SCREEN (Typing broadcast)
# ==========================================
chat = open("lib/chat_screen.dart").read()
chat = chat.replace(
    "  void _send() {",
    """  void _onTyping(String text) {
    SupabaseRealtime.sendTyping(_handle, text.isNotEmpty);
  }

  void _send() {"""
)
chat = chat.replace(
    "    _controller.clear();\n    setState(() => _replying = null);",
    "    _controller.clear();\n    _onTyping('');\n    setState(() => _replying = null);"
)
chat = chat.replace(
    "    _controller.addListener(() => setState(() {}));",
    "    _controller.addListener(() {\n      setState(() {});\n      _onTyping(_controller.text);\n    });"
)
# Add import
if "import 'supabase_realtime.dart';" not in chat:
    chat = chat.replace("import 'inbox_store.dart';", "import 'inbox_store.dart';\nimport 'supabase_realtime.dart';")
write_file("lib/chat_screen.dart", chat)

# ==========================================
# 13. CREATE THE FINAL ZIP
# ==========================================
print("📦 Creating Swifly_final.zip...")
zip_path = "/storage/emulated/0/Download/Swifly_final.zip"
if os.path.exists(zip_path): os.remove(zip_path)

with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk("."):
        if any(ignored in root for ignored in ['.git', 'build', '.dart_tool', 'node_modules']): continue
        for file in files:
            zf.write(os.path.join(root, file))

print(f"\n🎉 SUCCESS! Your full architecture fix is zipped at:\n{zip_path}")
