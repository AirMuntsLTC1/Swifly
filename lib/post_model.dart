import 'app_feedback.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'media/media_item.dart';
import 'native_bridge.dart';
import 'database_service.dart';
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
    'id': id, 'name': name, 'text': text,
    'created': created.toIso8601String(),
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
    this.shares = 0,
    List<CommentItem>? comments,
  }) : comments = comments ?? <CommentItem>[];

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

  /// Replaces all posts. Called with mock data now, database results later.
  void load({required List<Post> posts}) {
    _posts
      ..clear()
      ..addAll(posts);
    notifyListeners();
  }

  /// Your own new posts first (newest), then everyone else ranked by the C++ core.
  List<Post> get ranked {
    final validPosts = _posts.where((p) => p.text.trim().isNotEmpty || p.media.isNotEmpty).toList();
    final mine = validPosts.where((p) => p.authorHandle == kMeHandle).toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final others = validPosts.where((p) => p.authorHandle != kMeHandle).toList();
    final order = NativeCore.rankOrder(
      others.map((p) => p.likes).toList(),
      others.map((p) => p.totalComments).toList(),
      others.map((p) => p.saves).toList(),
      others.map((p) => p.hoursOld).toList(),
    );
    return [...mine, for (final i in order) others[i]];
  }

  /// How many posts a person has (used on their profile).
  int countFor(String handle) => _posts.where((p) => p.authorHandle == handle).length;

  /// Posts that are still being saved (their id is not a database id yet).
  List<Post> get unsaved => _posts.where((p) => !DatabaseService.isUuid(p.id)).toList();

  /// Everything you posted, newest first. Shown on your profile.
  List<Post> get myPosts => _posts.where((p) => p.authorHandle == kMeHandle).toList()
    ..sort((a, b) => b.created.compareTo(a.created));

  /// Call when the PHP pipeline finishes a photo or video that a post already shows.
  void mediaUpdated() => notifyListeners();

  Future<void> saveCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/feed_cache.json');
      final data = _posts.take(20).map((p) => p.toJson()).toList(); // Cache top 20 posts
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> loadCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/feed_cache.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as List;
        final cachedPosts = data.map((item) => Post.fromJson(item)).toList();
        // Only load cache if memory is empty (don't overwrite fresh data)
        if (_posts.isEmpty) {
          _posts.addAll(cachedPosts);
          notifyListeners();
        }
      }
    } catch (_) {}
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
  // Called by supabase_realtime.dart when another person likes, comments or saves.

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
      final serverId = await DatabaseService.instance.savePost(
          text, audience, taggedHandles, media);
      if (serverId != null) newPost.id = serverId;
    } catch (e) {
      reportError('Post not saved', e);
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
      reportError('Like not saved', e);
      p.liked = !p.liked;
      p.likes += p.liked ? 1 : -1;
      notifyListeners();
    }
  }

  /// Counts a share (the post was sent to [count] people in Messages).
  void registerShare(String id, int count) {
    final p = byId(id);
    if (p == null || count <= 0) return;
    p.shares += count;
    notifyListeners();
    DatabaseService.instance.registerShare(id, count).catchError((Object e) => reportError('Share not saved', e));
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
      reportError('Save not saved', e);
      p.saved = !p.saved;
      p.saves += p.saved ? 1 : -1;
      notifyListeners();
    }
  }

  Future<void> addReply(String postId, String commentId, String text) async {
    final p = byId(postId);
    if (p == null) return;

    CommentItem? parent;
    for (final c in p.comments) {
      if (c.id == commentId) {
        parent = c;
        break;
      }
    }
    if (parent == null) return;

    final newReply = CommentItem(name: kMeName, text: text, created: DateTime.now());
    parent.replies.add(newReply);
    notifyListeners();

    try {
      newReply.id = await DatabaseService.instance.addComment(postId, text, parentId: commentId);
    } catch (e) {
      reportError('Reply not sent', e);
      parent.replies.remove(newReply);
      notifyListeners();
    }
  }

  Future<void> addComment(String id, String text) async {
    final p = byId(id);
    if (p == null) return;

    final newComment = CommentItem(name: kMeName, text: text, created: DateTime.now());
    p.comments.add(newComment);
    notifyListeners();

    try {
      newComment.id = await DatabaseService.instance.addComment(id, text);
    } catch (e) {
      reportError('Comment not sent', e);
      p.comments.remove(newComment);
      notifyListeners();
    }
  }
}



