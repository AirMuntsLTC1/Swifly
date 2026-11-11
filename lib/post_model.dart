import 'package:flutter/foundation.dart';

import 'native_bridge.dart';
import 'tag_friends_screen.dart';
import 'database_service.dart';

const String kMeName = 'Your Name';
const String kMeHandle = '@yourhandle';

String nameForHandle(String handle) {
  for (final f in kFriends) {
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
  final List<String> mediaPaths;
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
    this.mediaPaths = const [],
    this.likes = 0,
    this.liked = false,
    this.saves = 0,
    this.saved = false,
    List<CommentItem>? comments,
  }) : comments = comments ?? <CommentItem>[];

  List<String> get hashtags => NativeCore.extractHashtags(text);
  bool hasHashtag(String tag) => NativeCore.countHashtag(text, tag) > 0;
  double get hoursOld => DateTime.now().difference(created).inSeconds / 3600.0;

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

  // Social Graph
  final Set<String> _myFollowing = {'@liampark', '@zaraali'};
  final Set<String> _myFollowers = {'@avastone', '@zaraali'};

  bool isFollowing(String handle) => _myFollowing.contains(handle);
  bool isFollower(String handle) => _myFollowers.contains(handle);
  int getFollowStatus(String handle) =>
      NativeCore.getFollowStatus(isFollowing(handle), isFollower(handle));

  void _seed() {
    // TODO: Replace _seed() with DatabaseService.instance.fetchPosts() when connecting DB
    final now = DateTime.now();
    _posts.addAll([
      Post(
        id: 's1',
        authorName: 'Ava Stone',
        authorHandle: '@avastone',
        text: 'Sunrise hike done. Worth every step. #hiking #travel',
        audience: 'Everyone',
        taggedHandles: const ['@liampark'],
        created: now.subtract(const Duration(hours: 2)),
        likes: 42,
        saves: 6,
        comments: [
          CommentItem(name: 'Liam Park', text: 'Looks amazing!', created: now),
        ],
      ),
      Post(
        id: 's2',
        authorName: 'Liam Park',
        authorHandle: '@liampark',
        text: 'Just shipped my first app! Feedback welcome. #coding #design',
        audience: 'Followers',
        taggedHandles: const ['@avastone', '@noahreed'],
        created: now.subtract(const Duration(hours: 4)),
        likes: 88,
        saves: 12,
      ),
      Post(
        id: 's3',
        authorName: 'Mia Chen',
        authorHandle: '@miachen',
        text: 'New coffee spot downtown. Highly recommend. #coffee',
        audience: 'Everyone',
        created: now.subtract(const Duration(hours: 6)),
        likes: 19,
        saves: 3,
      ),
      Post(
        id: 's4',
        authorName: 'Noah Reed',
        authorHandle: '@noahreed',
        text: 'Weekend project: a tiny plant-care tracker. #coding',
        audience: 'Followers',
        taggedHandles: const ['@zaraali'],
        created: now.subtract(const Duration(hours: 8)),
        likes: 7,
        saves: 1,
      ),
      Post(
        id: 's5',
        authorName: 'Zara Ali',
        authorHandle: '@zaraali',
        text: 'Books that changed how I think about design. #books #design',
        audience: 'Everyone',
        taggedHandles: const ['@hanasato'],
        created: now.subtract(const Duration(days: 1)),
        likes: 130,
        saves: 25,
      ),
    ]);
  }

  /// Your own new posts first (newest), then everyone else ranked by the C++ core.
  List<Post> get ranked {
    final mine = _posts.where((p) => p.authorHandle == kMeHandle).toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final others = _posts.where((p) => p.authorHandle != kMeHandle).toList();
    final order = NativeCore.rankOrder(
      others.map((p) => p.likes).toList(),
      others.map((p) => p.comments.length).toList(),
      others.map((p) => p.saves).toList(),
      others.map((p) => p.hoursOld).toList(),
    );
    return [...mine, for (final i in order) others[i]];
  }

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

  // --- ASYNC ACTIONS (Optimistic UI) ---

  Future<void> addPost({
    required String text,
    required String audience,
    required List<String> taggedHandles,
    List<String> mediaPaths = const [],
  }) async {
    final duplicate = _posts.any((p) =>
        p.authorHandle == kMeHandle &&
        p.text == text &&
        DateTime.now().difference(p.created).inSeconds < 2);
    if (duplicate) return;

    final newPost = Post(
      id: 'p${_nextId++}',
      authorName: kMeName,
      authorHandle: kMeHandle,
      text: text,
      audience: audience,
      taggedHandles: List<String>.of(taggedHandles),
      mediaPaths: mediaPaths,
      created: DateTime.now(),
    );

    _posts.insert(0, newPost);
    notifyListeners(); // Instantly update UI

    // DB Sync
    try {
      await DatabaseService.instance.savePost(text, audience, taggedHandles, mediaPaths);
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

  Future<void> toggleFollow(String handle) async {
    final wasFollowing = _myFollowing.contains(handle);
    if (wasFollowing) {
      _myFollowing.remove(handle);
    } else {
      _myFollowing.add(handle);
    }
    notifyListeners();

    try {
      await DatabaseService.instance.toggleFollow(handle, !wasFollowing);
    } catch (e) {
      if (wasFollowing) {
        _myFollowing.add(handle);
      } else {
        _myFollowing.remove(handle);
      }
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
