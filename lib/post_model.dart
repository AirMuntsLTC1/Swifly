import 'package:flutter/foundation.dart';

import 'native_bridge.dart';
import 'tag_friends_screen.dart';

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
  final String? imagePath;
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
    this.imagePath,
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

  final Set<String> _myFollowing = {'@liampark', '@zaraali'};
  final Set<String> _myFollowers = {'@avastone', '@zaraali'};

  bool isFollowing(String handle) => _myFollowing.contains(handle);
  bool isFollower(String handle) => _myFollowers.contains(handle);
  int getFollowStatus(String handle) => NativeCore.getFollowStatus(isFollowing(handle), isFollower(handle));
  void toggleFollow(String handle) {
    if (_myFollowing.contains(handle)) {
      _myFollowing.remove(handle);
    } else {
      _myFollowing.add(handle);
    }
    notifyListeners();
  }

  void _seed() {
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

  /// Number of distinct users (authors) that used [tag].
  int hashtagUsage(String tag) {
    final users = <String>{};
    for (final p in _posts) {
      if (p.hasHashtag(tag)) users.add(p.authorHandle);
    }
    return users.length;
  }

  /// All posts (newest first) that contain [tag].
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

  void addPost({
    required String text,
    required String audience,
    required List<String> taggedHandles,
    String? imagePath,
  }) {
    final duplicate = _posts.any((p) =>
        p.authorHandle == kMeHandle &&
        p.text == text &&
        DateTime.now().difference(p.created).inSeconds < 2);
    if (duplicate) return;
    _posts.insert(
      0,
      Post(
        id: 'p${_nextId++}',
        authorName: kMeName,
        authorHandle: kMeHandle,
        text: text,
        audience: audience,
        taggedHandles: List<String>.of(taggedHandles),
        imagePath: imagePath,
        created: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void toggleLike(String id) {
    final p = byId(id);
    if (p == null) return;
    p.liked = !p.liked;
    p.likes += p.liked ? 1 : -1;
    notifyListeners();
  }

  void toggleSave(String id) {
    final p = byId(id);
    if (p == null) return;
    p.saved = !p.saved;
    p.saves += p.saved ? 1 : -1;
    notifyListeners();
  }

  void addReply(String postId, String commentId, String text) {
    final p = byId(postId);
    if (p == null) return;
    for (final c in p.comments) {
      if (c.id == commentId) {
        c.replies.add(CommentItem(name: kMeName, text: text, created: DateTime.now()));
        break;
      }
    }
    notifyListeners();
  }

  void addComment(String id, String text) {
    final p = byId(id);
    if (p == null) return;
    p.comments.add(CommentItem(name: kMeName, text: text, created: DateTime.now()));
    notifyListeners();
  }
}
