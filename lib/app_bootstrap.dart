import 'database_service.dart';
import 'db_mappers.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'people_directory.dart';
import 'post_model.dart';
import 'profile_store.dart';
import 'supabase_config.dart';
import 'supabase_realtime.dart';

/// The single place where the app gets its starting data. Everything comes from
/// Supabase (through DatabaseService). Screens never need to know where it came from.
Future<void> loadAppData() async {
  if (!kAuthEnabled) return;
  await _loadFromDatabase();
}

/// Starts the live listener (Supabase Realtime). Safe to call more than once.
void startLiveActivity() {
  if (!kAuthEnabled) return;
  SupabaseRealtime.start();
}

/// Reloads the feed from the database. Used when someone else publishes a post.
Future<void> refreshPosts() async {
  final rows = await DatabaseService.instance.fetchPosts();
  PostStore.instance.load(posts: [for (final r in rows) postFromRow(r)]);
}

Future<void> _loadFromDatabase() async {
  final db = DatabaseService.instance;

  // Each block is independent: one table failing never blocks the others.
  Future<void> safe(Future<void> Function() job) async {
    try {
      await job().timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  await Future.wait([
    safe(() async {
      final me = await db.fetchMe();
      if (me != null) {
        final name = me['name'] ?? me['display_name'];
        final handle = me['handle'] ?? (me['username'] == null ? null : '@${me['username']}');
        if (name != null) CurrentUser.name = name.toString();
        if (handle != null) CurrentUser.handle = handle.toString();
      }
    }),
    safe(() async {
      final rows = await db.fetchPeople();
      final tags = await db.fetchTrendingTags();
      PeopleDirectory.instance.load(
        people: [for (final r in rows) personFromRow(r)],
        stats: statsFromRows(rows),
        trending: tags,
      );
    }),
    safe(() => refreshPosts()),
    safe(() async {
      final f = await db.fetchFollows();
      FollowStore.instance.load(
        following: (f['following'] ?? <String>[]).toSet(),
        followers: (f['followers'] ?? <String>[]).toSet(),
      );
    }),
    safe(() async {
      final rows = await db.fetchNotifications();
      NotificationStore.instance.load([for (final r in rows) notificationFromRow(r)]);
    }),
    safe(() async {
      final rows = await db.fetchMessages();
      ChatStore.instance.load(threadsFromRows(rows));
    }),
    safe(() async {
      final rows = await db.fetchNotes();
      NoteStore.instance.load(notesFromRows(rows));
    }),
    safe(() => ProfileStore.instance.loadFromDatabase()),
  ]);
}

/// Empties every store and stops the live listener. Used on log out so the
/// next person never sees old data.
Future<void> clearAppData() async {
  try {
    await SupabaseRealtime.stop();
  } catch (_) {}
  CurrentUser.name = 'Your Name';
  CurrentUser.handle = '@yourhandle';
  PeopleDirectory.instance.load();
  PostStore.instance.load(posts: <Post>[]);
  FollowStore.instance.load();
  NotificationStore.instance.load(<AppNotification>[]);
  ChatStore.instance.load(<String, List<ChatMessage>>{});
  NoteStore.instance.load(<String, DmNote>{});
  await ProfileStore.instance.clearDevice();
}
