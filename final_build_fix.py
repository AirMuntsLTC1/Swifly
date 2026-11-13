import os
import shutil

def apply_fix(filepath, old_text, new_text, description):
    if not os.path.exists(filepath):
        print(f"❌ Could not find {filepath}")
        return
    shutil.copyfile(filepath, filepath + ".bak2")
    with open(filepath, 'r') as f: content = f.read()
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f: f.write(content)
        print(f"✅ Fixed: {description}")
    else:
        print(f"⚠️ Skipped: {description} (pattern not found)")

print("Fixing final build errors...\n")

# 1. THE ACTUAL COMPILE ERROR: fetchNotifications using undefined offset/limit
apply_fix(
    "lib/database_service.dart",
    """  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final rows = await _db
        .from('notifications')
        .select('*')
        .eq('user_id', _requireMe())
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }""",
    """  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final rows = await _db
        .from('notifications')
        .select('*')
        .eq('user_id', _requireMe())
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }""",
    "Fixed fetchNotifications (removed undefined offset/limit)"
)

# 2. DmAvatar name shadowing - now it actually uses the passed name
apply_fix(
    "lib/dm_theme.dart",
    """    final path = isMe ? ProfileStore.instance.avatarPath : null;
    final name = isMe ? kMeName : nameForHandle(handle);""",
    """    final path = isMe ? ProfileStore.instance.avatarPath : null;
    final displayName = this.name ?? (isMe ? kMeName : nameForHandle(handle));""",
    "Fixed DmAvatar to use passed name"
)
apply_fix(
    "lib/dm_theme.dart",
    """    final letter = name.replaceAll('@', '').trim().isEmpty
        ? '?'
        : name.replaceAll('@', '').trim().characters.first.toUpperCase();""",
    """    final letter = displayName.replaceAll('@', '').trim().isEmpty
        ? '?'
        : displayName.replaceAll('@', '').trim().characters.first.toUpperCase();""",
    "Use displayName for avatar letter"
)

# 3. Restore offline cache + realtime in Splash Screen
apply_fix(
    "lib/splash_screen.dart",
    "import 'app_bootstrap.dart';",
    "import 'app_bootstrap.dart';\nimport 'post_model.dart';",
    "Added post_model import to splash"
)
apply_fix(
    "lib/splash_screen.dart",
    """        AuthService.instance.applyUser();
        setState(() => _status = 'Loading your feed...');
        await loadAppData();""",
    """        AuthService.instance.applyUser();
        setState(() => _status = 'Loading your feed...');
        await PostStore.instance.loadCache();
        await loadAppData();
        startLiveActivity();""",
    "Restored offline cache and live activity in splash"
)

print("\n🎉 All fixes applied! Now run flutter clean && flutter pub get && build.")
