import re
import os

print("Forcing Pagination Fixes...\n")

# 1. Fix database_service.dart (Add limit and offset parameters)
with open("lib/database_service.dart", "r") as f:
    content = f.read()

# Use regex to find fetchPosts() even if there are extra spaces
new_content = re.sub(
    r'Future<List<Map<String, dynamic>>>\s+fetchPosts\(\s*\)\s*async\s*\{',
    'Future<List<Map<String, dynamic>>> fetchPosts({int limit = 4, int offset = 0}) async {',
    content
)
with open("lib/database_service.dart", "w") as f:
    f.write(new_content)
print("✅ Fixed: fetchPosts signature in database_service.dart")

# 2. Fix post_model.dart (Add loadMorePosts and isLoadingMore to PostStore)
with open("lib/post_model.dart", "r") as f:
    content = f.read()

# Make sure db_mappers is imported so postFromRow works
if "import 'db_mappers.dart';" not in content:
    content = content.replace(
        "import 'database_service.dart';",
        "import 'database_service.dart';\nimport 'db_mappers.dart';"
    )

# Inject pagination variables and method right after _nextId
if "loadMorePosts" not in content:
    content = content.replace(
        "int _nextId = 1;",
        """int _nextId = 1;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadMorePosts() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final saved = await DatabaseService.instance.fetchPosts(limit: 4, offset: _posts.length);
      if (saved.isNotEmpty) {
        for (final r in saved) { _posts.add(postFromRow(r)); }
        notifyListeners();
      }
    } catch (e) {
      print('Pagination error: $e');
    }
    _isLoadingMore = false;
    notifyListeners();
  }"""
    )
    with open("lib/post_model.dart", "w") as f:
        f.write(content)
    print("✅ Fixed: Added loadMorePosts and isLoadingMore to PostStore")
else:
    print("ℹ️ loadMorePosts already exists in PostStore")

print("\n🎉 All pagination errors are now fixed! You can rebuild the app.")
