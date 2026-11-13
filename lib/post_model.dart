import 'app_feedback.dart';
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
