import 'app_feedback.dart';
import 'database_service.dart';
import 'db_mappers.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'people_directory.dart';
import 'post_model.dart';
import 'profile_store.dart';
import 'supabase_config.dart';
import 'supabase_realtime.dart';
import 'startup_timer.dart';

bool _loading = false;
bool _pendingReload = false;

Future<void> loadAppData() async {
  if (!kAuthEnabled) return;
  if (_loading) { _pendingReload = true; return; }
  _loading = true;
  StartupTimer.log('loadAppData started');

  try {
    await _loadFromDatabase();
  } finally {
    _loading = false;
    StartupTimer.log('loadAppData finished');
    if (_pendingReload) {
      _pendingReload = false;
      loadAppData();
    }
  }
}

Future<void> refreshPosts() async {
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

void startLiveActivity() {
  if (!kAuthEnabled) return;
  SupabaseRealtime.start();
}

Future<void> _loadFromDatabase() async {
  final db = DatabaseService.instance;
  await Future.wait([
    db.fetchMe().then((me) { if (me != null) { CurrentUser.name = me['name'] ?? me['display_name']; CurrentUser.handle = me['handle']; } }).catchError((_) {}),
    db.fetchPeople().then((rows) => PeopleDirectory.instance.load(people: rows.map(personFromRow).toList(), stats: statsFromRows(rows))).catchError((_) {}),
    db.fetchPosts(limit: 20, offset: 0).then((rows) => PostStore.instance.merge(newPosts: rows.map(postFromRow).toList())).catchError((_) {}),
    db.fetchFollows().then((f) => FollowStore.instance.load(following: (f['following'] ?? []).toSet(), followers: (f['followers'] ?? []).toSet())).catchError((_) {}),
    db.fetchNotifications().then((rows) => NotificationStore.instance.load(rows.map(notificationFromRow).toList())).catchError((_) {}),
    db.fetchMessages().then((rows) => ChatStore.instance.load(threadsFromRows(rows))).catchError((_) {}),
    ProfileStore.instance.loadFromDatabase().catchError((_) {}),
  ]);
}

Future<void> clearAppData() async {
  try { await SupabaseRealtime.stop(); } catch (_) {}
  CurrentUser.name = 'Your Name'; CurrentUser.handle = '@yourhandle';
  PeopleDirectory.instance.load();
  PostStore.instance.load(posts: []);
  await PostStore.instance.clearCache();
  FollowStore.instance.load();
  NotificationStore.instance.load([]);
  ChatStore.instance.reset();
  await ProfileStore.instance.clearDevice();
  await DatabaseService.instance.clearLocalMediaCache();
}
