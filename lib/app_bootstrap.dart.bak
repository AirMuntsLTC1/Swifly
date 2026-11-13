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

/// Reloads the feed from the database. Posts that are still being saved on this
/// phone are kept, so a refresh never makes a new post vanish.
Future<void> refreshPosts() async {
  final saved = await DatabaseService.instance.fetchPosts();
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
  ]);
}

/// Loads active stories: my own (with its reactions and replies) and the
/// stories of people I follow.
Future<void> refreshStories() async {
  final rows = await DatabaseService.instance.fetchStories();
  final others = <String, OtherStory>{};
  var mineOnServer = false;
  for (final r in rows) {
    final story = storyFromRow(r);
    final handle = '${r['handle']}';
    if (handle == kMeHandle) {
      mineOnServer = true;
      StoryStore.instance.loadMine(story);
      final id = story.id;
      if (id != null && id.isNotEmpty) {
        final activity = await DatabaseService.instance.fetchStoryActivity(id);
        final reactions = [
          for (final a in activity['reactions']!)
            StoryReaction(
              name: '${a['name']}',
              handle: '${a['handle']}',
              emoji: '${a['emoji']}',
              time: DateTime.tryParse('${a['created_at']}')?.toLocal() ?? DateTime.now(),
            ),
        ];
        final replies = [
          for (final a in activity['replies']!)
            StoryReply(
              name: '${a['name']}',
              handle: '${a['handle']}',
              text: '${a['text']}',
              time: DateTime.tryParse('${a['created_at']}')?.toLocal() ?? DateTime.now(),
            ),
        ];
        StoryStore.instance.loadActivity(reactions, replies);
      }
    } else {
      others[handle] = story;
    }
  }
  // Clear my story only if it was saved before and is gone now. A story that is
  // still being saved is kept.
  if (!mineOnServer && StoryStore.instance.storyId != null) {
    StoryStore.instance.delete();
  }
  StoryStore.instance.loadOthers(others);
}

Future<void> _loadFromDatabase() async {
  final db = DatabaseService.instance;

  // Each block is independent: one part failing never blocks the others,
  // and the reason is shown on screen instead of being hidden.
  Future<void> step(String what, Future<void> Function() job) async {
    try {
      await job().timeout(const Duration(seconds: 12));
    } catch (e) {
      reportError("Couldn't load $what", e);
    }
  }

  await Future.wait([
    step('your profile', () async {
      final me = await db.fetchMe();
      if (me != null) {
        final name = me['name'] ?? me['display_name'];
        final handle = me['handle'] ?? (me['username'] == null ? null : '@${me['username']}');
        if (name != null) CurrentUser.name = name.toString();
        if (handle != null) CurrentUser.handle = handle.toString();
      }
    }),
    step('people', () async {
      final rows = await db.fetchPeople();
      final tags = await db.fetchTrendingTags();
      PeopleDirectory.instance.load(
        people: [for (final r in rows) personFromRow(r)],
        stats: statsFromRows(rows),
        trending: tags,
      );
    }),
    step('posts', () => refreshPosts()),
    step('follows', () async {
      final f = await db.fetchFollows();
      FollowStore.instance.load(
        following: (f['following'] ?? <String>[]).toSet(),
        followers: (f['followers'] ?? <String>[]).toSet(),
      );
    }),
    step('notifications', () async {
      final rows = await db.fetchNotifications();
      NotificationStore.instance.load([for (final r in rows) notificationFromRow(r)]);
    }),
    step('messages', () async {
      final rows = await db.fetchMessages();
      ChatStore.instance.load(threadsFromRows(rows));
    }),
    step('notes', () async {
      final rows = await db.fetchNotes();
      NoteStore.instance.load(notesFromRows(rows));
    }),
    step('stories', () => refreshStories()),
    step('profile details', () => ProfileStore.instance.loadFromDatabase()),
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
  StoryStore.instance.delete();
  StoryStore.instance.loadOthers(<String, OtherStory>{});
  await ProfileStore.instance.clearDevice();
}
