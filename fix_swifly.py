import os
import shutil

def apply_fix(filepath, old_text, new_text, description):
    if not os.path.exists(filepath):
        print(f"❌ Could not find {filepath}")
        return
    
    shutil.copyfile(filepath, filepath + ".bak")
    
    with open(filepath, 'r') as f:
        content = f.read()
        
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ Fixed: {description}")
    else:
        print(f"⚠️ Skipped: {description} (code already changed or not found)")

print("Starting Swifly App Fixes...\n")

# 1. Fix Duplicate Posts
apply_fix(
    "lib/app_bootstrap.dart",
    """  final saved = await DatabaseService.instance.fetchPosts();
  final pending = PostStore.instance.unsaved;
  PostStore.instance.load(posts: [
    ...pending,
    for (final r in saved) postFromRow(r),
  ]);""",
    """  final saved = await DatabaseService.instance.fetchPosts();
  final pending = PostStore.instance.unsaved;
  
  final filteredSaved = saved.where((savedRow) {
    final savedText = '${savedRow['text'] ?? ''}'.trim();
    final savedMediaLen = (savedRow['media'] as List?)?.length ?? 0;
    for (final local in pending) {
      if (local.text.trim() == savedText && local.media.length == savedMediaLen) {
        return false;
      }
    }
    return true;
  }).toList();

  PostStore.instance.load(posts: [
    ...pending,
    for (final r in filteredSaved) postFromRow(r),
  ]);""",
    "Prevent duplicate posts in feed"
)

# 2. Filter Empty Posts
apply_fix(
    "lib/post_model.dart",
    """  List<Post> get ranked {
    final mine = _posts.where((p) => p.authorHandle == kMeHandle).toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final others = _posts.where((p) => p.authorHandle != kMeHandle).toList();""",
    """  List<Post> get ranked {
    final validPosts = _posts.where((p) => p.text.trim().isNotEmpty || p.media.isNotEmpty).toList();
    final mine = validPosts.where((p) => p.authorHandle == kMeHandle).toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final others = validPosts.where((p) => p.authorHandle != kMeHandle).toList();""",
    "Filter out completely empty posts"
)

# 3. Fix Empty Chat Bubbles
apply_fix(
    "lib/inbox_store.dart",
    """  void _add(String handle, ChatMessage m) {
    _threads.putIfAbsent(handle, () => <ChatMessage>[]).add(m);
    notifyListeners();
  }""",
    """  void _add(String handle, ChatMessage m) {
    final cleanText = m.text.replaceAll('\\u200B', '').trim();
    if (cleanText.isEmpty && m.post == null && m.story == null && m.replyTo == null) {
      return;
    }
    _threads.putIfAbsent(handle, () => <ChatMessage>[]).add(m);
    notifyListeners();
  }""",
    "Prevent empty chat messages"
)

# 4. Refresh Profile Details After Saving
apply_fix(
    "lib/edit_profile_screen.dart",
    """    final store = ProfileStore.instance;
    store.setValue(d.key, _valueToSave);
    store.setAudience(d.key, _audience);
    _rememberPicks();
    Navigator.pop(context);""",
    """    final store = ProfileStore.instance;
    store.setValue(d.key, _valueToSave);
    store.setAudience(d.key, _audience);
    _rememberPicks();
    store.loadFromDatabase(); // Force refresh
    Navigator.pop(context);""",
    "Refresh profile UI after saving a field"
)

print("\nAll fixes applied! You can now rebuild your app.")
