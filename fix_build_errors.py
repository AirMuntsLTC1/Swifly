import os
import shutil

def apply_fix(filepath, old_text, new_text, description):
    if not os.path.exists(filepath):
        print(f"❌ Could not find {filepath}")
        return
    shutil.copyfile(filepath, filepath + ".bak")
    with open(filepath, 'r') as f: content = f.read()
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f: f.write(content)
        print(f"✅ Fixed: {description}")
    else:
        print(f"⚠️ Skipped: {description} (code already changed or pattern not found)")

print("Fixing Build Errors...\n")

# 1. Fix DmAvatar constructor & missing ternary in dm_theme.dart
apply_fix(
    "lib/dm_theme.dart",
    "const DmAvatar({super.key, required this.handle, this.size = 56, this.ring = false, this.gap});",
    "const DmAvatar({super.key, required this.handle, this.name, this.size = 56, this.ring = false, this.gap});\n  final String? name;",
    "Added 'name' parameter to DmAvatar constructor"
)
apply_fix(
    "lib/dm_theme.dart",
    "child: !hasImage\n          ? Text(letter,\n              style: TextStyle(\n                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: inner * 0.42)),",
    "child: !hasImage\n          ? Text(letter,\n              style: TextStyle(\n                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: inner * 0.42))\n          : null,",
    "Fixed missing ternary operator (': null') for avatar fallback"
)

# 2. Fix fetchPosts parameters in database_service.dart
apply_fix(
    "lib/database_service.dart",
    "Future<List<Map<String, dynamic>>> fetchPosts() async {",
    "Future<List<Map<String, dynamic>>> fetchPosts({int limit = 4, int offset = 0}) async {",
    "Added 'limit' and 'offset' parameters to fetchPosts"
)

# 3. Fix missing loadMorePosts and isLoadingMore in post_model.dart
apply_fix(
    "lib/post_model.dart",
    "class PostStore extends ChangeNotifier {\n  PostStore._();\n  static final PostStore instance = PostStore._();\n  final List<Post> _posts = [];\n  int _nextId = 1;",
    "class PostStore extends ChangeNotifier {\n  PostStore._();\n  static final PostStore instance = PostStore._();\n  final List<Post> _posts = [];\n  int _nextId = 1;\n  bool _isLoadingMore = false;\n  bool get isLoadingMore => _isLoadingMore;\n\n  Future<void> loadMorePosts() async {\n    if (_isLoadingMore) return;\n    _isLoadingMore = true;\n    notifyListeners();\n    try {\n      final saved = await DatabaseService.instance.fetchPosts(limit: 4, offset: _posts.length);\n      if (saved.isNotEmpty) {\n        for (final r in saved) { _posts.add(postFromRow(r)); }\n        notifyListeners();\n      }\n    } catch (e) {\n      // ignore\n    }\n    _isLoadingMore = false;\n    notifyListeners();\n  }",
    "Added loadMorePosts and isLoadingMore to PostStore"
)

print("\n🎉 All build errors fixed! You can now rebuild the app.")
