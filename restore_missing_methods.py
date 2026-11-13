import os
import shutil

def apply_fix(filepath, old_text, new_text, description):
    if not os.path.exists(filepath):
        print(f"❌ Could not find {filepath}")
        return
    shutil.copyfile(filepath, filepath + ".bak3")
    with open(filepath, 'r') as f: content = f.read()
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f: f.write(content)
        print(f"✅ Fixed: {description}")
    else:
        print(f"⚠️ Skipped: {description} (pattern not found)")

print("Restoring missing methods and fixing imports...\n")

# 1. Add missing PostStore methods (addComment, addReply, search, postsWithHashtag, registerShare)
apply_fix(
    "lib/post_model.dart",
    "  Future<void> toggleLike(String id) async {",
    """  List<Post> postsWithHashtag(String tag) {
    return _posts.where((p) => p.hasHashtag(tag)).toList()..sort((a, b) => b.created.compareTo(a.created));
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

  bool applyComment({required String postId, required String id, required String name, required String text, String? parentId}) {
    final p = byId(postId);
    if (p == null) return false;
    final exists = p.comments.any((c) => c.id == id || c.replies.any((r) => r.id == id));
    if (exists) return false;

    final item = CommentItem(id: id, name: name, text: text, created: DateTime.now());
    if (parentId == null) {
      p.comments.add(item);
    } else {
      CommentItem? parent;
      for (final c in p.comments) { if (c.id == parentId) { parent = c; break; } }
      if (parent == null) return false;
      parent.replies.add(item);
    }
    notifyListeners();
    return true;
  }

  void registerShare(String id, int count) {
    final p = byId(id);
    if (p == null || count <= 0) return;
    p.shares += count;
    notifyListeners();
    DatabaseService.instance.registerShare(id, count).catchError((Object e) => reportError('Share not saved', e));
  }

  Future<void> addReply(String postId, String commentId, String text) async {
    final p = byId(postId);
    if (p == null) return;
    CommentItem? parent;
    for (final c in p.comments) { if (c.id == commentId) { parent = c; break; } }
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

  Future<void> toggleLike(String id) async {""",
    "Restored PostStore methods (addComment, search, etc.)"
)

# 2. Add insertFromRow to NotificationStore
apply_fix(
    "lib/inbox_store.dart",
    "  void markAllRead() {",
    """  void insertFromRow(Map<String, dynamic> row) {
    final n = AppNotification(
      id: '${row['id']}',
      type: NotifType.values.firstWhere((t) => t.name == row['type'], orElse: () => NotifType.like),
      actorName: '${row['actor_name'] ?? ''}',
      actorHandle: '${row['actor_handle'] ?? ''}',
      created: DateTime.tryParse('${row['created_at']}')?.toLocal() ?? DateTime.now(),
      postId: row['post_id']?.toString(),
      commentId: row['comment_id']?.toString(),
      emoji: row['emoji']?.toString(),
      preview: row['preview']?.toString(),
      read: row['read'] == true,
    );
    _items.insert(0, n);
    notifyListeners();
    _incoming.add(n);
  }

  void markAllRead() {""",
    "Added insertFromRow to NotificationStore"
)

# 3. Restore refreshPosts in app_bootstrap
apply_fix(
    "lib/app_bootstrap.dart",
    "void startLiveActivity() {",
    """Future<void> refreshPosts() async {
  final saved = await DatabaseService.instance.fetchPosts(limit: 20, offset: 0);
  final pending = PostStore.instance.unsaved;
  
  final filteredSaved = saved.where((savedRow) {
    final savedText = '${savedRow['text'] ?? ''}'.trim();
    final savedMediaLen = (savedRow['media'] as List?)?.length ?? 0;
    for (final local in pending) {
      if (local.text.trim() == savedText && local.media.length == savedMediaLen) return false;
    }
    return true;
  }).toList();

  PostStore.instance.merge(newPosts: [
    for (final r in filteredSaved) postFromRow(r),
  ]);
}

void startLiveActivity() {""",
    "Restored refreshPosts in app_bootstrap"
)

# 4. Fix realtime_router import
apply_fix(
    "lib/realtime_router.dart",
    "import 'realtime.dart';",
    "import 'realtime.dart';\nimport 'database_service.dart';",
    "Added DatabaseService import to realtime_router"
)

# 5. Fix auth_flow import
apply_fix(
    "lib/auth/auth_flow.dart",
    "import '../home_screen.dart';",
    "import '../home_screen.dart';\nimport '../post_model.dart';",
    "Added PostStore import to auth_flow"
)

print("\n🎉 All missing methods restored! Now rebuild.")
