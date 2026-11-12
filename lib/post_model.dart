import 'package:flutter/foundation.dart';

import 'media/media_item.dart';
import 'native_bridge.dart';
import 'tag_friends_screen.dart';
import 'database_service.dart';

const String kMeName = 'Your Name';
const String kMeHandle = '@yourhandle';

/// The user's own demo post. Incoming likes, comments and saves land here.
const String kMyPostId = 'm1';

String nameForHandle(String handle) {
  for (final f in kPeople) {
    if (f.handle == handle) return f.name;
  }
  return handle;
}

int _commentSeq = 0;

class CommentItem {
  final String id;
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
}

class Post {
  final String id;
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

  Post({
    required this.id,
    required this.authorName,
    required this.authorHandle,
    required this.text,
    required this.audience,
    required this.created,
    this.taggedHandles = const [],
    this.media = const [],
    this.likes = 0,
    this.liked = false,
    this.saves = 0,
    this.saved = false,
    List<CommentItem>? comments,
  }) : comments = comments ?? <CommentItem>[];

  /// Paths of the files, kept for code that only needs the list of files.
  List<String> get mediaPaths => media.map((m) => m.path).toList();

  List<String> get hashtags => NativeCore.extractHashtags(text);
  bool hasHashtag(String tag) => NativeCore.countHashtag(text, tag) > 0;
  double get hoursOld => DateTime.now().difference(created).inSeconds / 3600.0;

  /// Top-level comments plus all replies. Every count on screen uses this.
  int get totalComments => comments.fold<int>(0, (n, c) => n + 1 + c.replies.length);

  String get timeLabel {
    final d = DateTime.now().difference(created);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

class PostStore extends ChangeNotifier {
  PostStore._() {
    _seed();
  }

  static final PostStore instance = PostStore._();

  final List<Post> _posts = [];
  int _nextId = 1;

  void _seed() {
    // TODO: Replace _seed() with DatabaseService.instance.fetchPosts() when connecting DB
    // Sample data lives in mock_data.dart (see kUseMockData in app_config.dart).
  }

  /// Replaces all posts. Called with mock data now, database results later.
  void load({required List<Post> posts}) {
    _posts
      ..clear()
      ..addAll(posts);
    notifyListeners();
  }

  /// Your own new posts first (newest), then everyone else ranked by the C++ core.
  List<Post> get ranked {
    final mine = _posts.where((p) => p.authorHandle == kMeHandle).toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final others = _posts.where((p) => p.authorHandle != kMeHandle).toList();
    final order = NativeCore.rankOrder(
      others.map((p) => p.likes).toList(),
      others.map((p) => p.totalComments).toList(),
      others.map((p) => p.saves).toList(),
      others.map((p) => p.hoursOld).toList(),
    );
    return [...mine, for (final i in order) others[i]];
  }

  /// Everything you posted, newest first. Shown on your profile.
  List<Post> get myPosts => _posts.where((p) => p.authorHandle == kMeHandle).toList()
    ..sort((a, b) => b.created.compareTo(a.created));

  /// Call when the PHP pipeline finishes a photo or video that a post already shows.
  void mediaUpdated() => notifyListeners();

  int hashtagUsage(String tag) {
    final users = <String>{};
    for (final p in _posts) {
      if (p.hasHashtag(tag)) users.add(p.authorHandle);
    }
    return users.length;
  }

  List<Post> postsWithHashtag(String tag) {
    final list = _posts.where((p) => p.hasHashtag(tag)).toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    return list;
  }

  Post? byId(String id) {
    for (final p in _posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Post> search(String query) {
    return _posts.where((p) {
      if (NativeCore.containsCI(p.text, query)) return true;
      if (NativeCore.containsCI(p.authorName, query)) return true;
      for (final h in p.taggedHandles) {
        if (NativeCore.containsCI(nameForHandle(h), query)) return true;
        if (NativeCore.containsCI(h, query)) return true;
      }
      return false;
    }).toList();
  }

  // --- INCOMING ACTIVITY FROM OTHER PEOPLE ---
  // A real backend would deliver these as push events. MockRealtime calls them in demo mode.

  bool receiveLike(String postId) {
    final p = byId(postId);
    if (p == null) return false;
    p.likes++;
    notifyListeners();
    return true;
  }

  bool receiveSave(String postId) {
    final p = byId(postId);
    if (p == null) return false;
    p.saves++;
    notifyListeners();
    return true;
  }

  /// Adds a comment or reply from another person. Returns false if the post or
  /// parent comment is missing, or if this id was already applied.
  bool applyComment({
    required String postId,
    required String id,
    required String name,
    required String text,
    String? parentId,
  }) {
    final p = byId(postId);
    if (p == null) return false;
    final exists = p.comments.any(
        (c) => c.id == id || c.replies.any((r) => r.id == id));
    if (exists) return false;

    final item = CommentItem(id: id, name: name, text: text, created: DateTime.now());
    if (parentId == null) {
      p.comments.add(item);
    } else {
      CommentItem? parent;
      for (final c in p.comments) {
        if (c.id == parentId) {
          parent = c;
          break;
        }
      }
      if (parent == null) return false;
      parent.replies.add(item);
    }
    notifyListeners();
    return true;
  }

  // --- ASYNC ACTIONS (Optimistic UI) ---

  Future<void> addPost({
    required String text,
    required String audience,
    required List<String> taggedHandles,
    List<MediaItem> media = const [],
  }) async {
    final duplicate = _posts.any((p) =>
        p.authorHandle == kMeHandle &&
        p.text == text &&
        p.media.length == media.length &&
        DateTime.now().difference(p.created).inSeconds < 2);
    if (duplicate) return;

    final newPost = Post(
      id: 'p${_nextId++}',
      authorName: kMeName,
      authorHandle: kMeHandle,
      text: text,
      audience: audience,
      taggedHandles: List<String>.of(taggedHandles),
      media: media,
      created: DateTime.now(),
    );

    _posts.insert(0, newPost);
    notifyListeners(); // Instantly update UI

    // DB Sync
    try {
      await DatabaseService.instance.savePost(
          text, audience, taggedHandles, media.map((m) => m.path).toList());
    } catch (e) {
      _posts.removeWhere((p) => p.id == newPost.id);
      notifyListeners(); // Rollback on error
    }
  }

  Future<void> toggleLike(String id) async {
    final p = byId(id);
    if (p == null) return;

    p.liked = !p.liked;
    p.likes += p.liked ? 1 : -1;
    notifyListeners();

    try {
      await DatabaseService.instance.toggleLike(id, p.liked);
    } catch (e) {
      p.liked = !p.liked;
      p.likes += p.liked ? 1 : -1;
      notifyListeners();
    }
  }

  Future<void> toggleSave(String id) async {
    final p = byId(id);
    if (p == null) return;

    p.saved = !p.saved;
    p.saves += p.saved ? 1 : -1;
    notifyListeners();

    try {
      await DatabaseService.instance.toggleSave(id, p.saved);
    } catch (e) {
      p.saved = !p.saved;
      p.saves += p.saved ? 1 : -1;
      notifyListeners();
    }
  }

  Future<void> addReply(String postId, String commentId, String text) async {
    final p = byId(postId);
    if (p == null) return;
    
    final newReply = CommentItem(name: kMeName, text: text, created: DateTime.now());
    for (final c in p.comments) {
      if (c.id == commentId) {
        c.replies.add(newReply);
        break;
      }
    }
    notifyListeners();

    try {
      await DatabaseService.instance.addComment(postId, text);
    } catch (e) {
      // Rollback logic if needed
    }
  }

  Future<void> addComment(String id, String text) async {
    final p = byId(id);
    if (p == null) return;

    final newComment = CommentItem(name: kMeName, text: text, created: DateTime.now());
    p.comments.add(newComment);
    notifyListeners();

    try {
      await DatabaseService.instance.addComment(id, text);
    } catch (e) {
      p.comments.remove(newComment);
      notifyListeners();
    }
  }
}


