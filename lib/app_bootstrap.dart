import 'dart:async';

import 'app_config.dart';
import 'database_service.dart';
import 'db_mappers.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'mock/mock_data.dart';
import 'mock/mock_realtime.dart';
import 'people_directory.dart';
import 'post_model.dart';
import 'profile_store.dart';

/// The single place where the app gets its starting data.
///
///  kUseMockData = true  -> sample users, posts, chats (lib/mock/)
///  kUseMockData = false -> everything below comes from DatabaseService
///
/// Screens never know which one is running, so the design stays identical.
Future<void> loadAppData() async {
  if (kUseMockData) {
    loadMockData();
    return;
  }
  await _loadFromDatabase();
}

/// Starts simulated live activity (mock) or, later, your Supabase realtime listener.
void startLiveActivity() {
  if (kUseMockData) {
    MockRealtime.start();
    return;
  }
  // TODO(supabase): subscribe to realtime changes here and call
  // Realtime.instance.publish(...) with the same events MockRealtime sends.
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
    safe(() async {
      final rows = await db.fetchPosts();
      PostStore.instance.load(posts: [for (final r in rows) postFromRow(r)]);
    }),
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

/// Empties every store. Used on log out so the next person never sees old data.
Future<void> clearAppData() async {
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
