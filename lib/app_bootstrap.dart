import 'package:flutter/foundation.dart';

import 'app_feedback.dart';
import 'avatar_cache.dart';
import 'database_service.dart';
import 'db_mappers.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'local_cache.dart';
import 'new_connections.dart';
import 'people_directory.dart';
import 'post_model.dart';
import 'profile_store.dart';
import 'supabase_config.dart';
import 'supabase_realtime.dart';
import 'startup_timer.dart';

bool _loading = false;
bool _pendingReload = false;

/// Step 1 of startup, instant: fills people and follows from the last saved copy
/// on the phone. No network. The screens can show something right away.
Future<void> loadLocalAppData() async {
  if (!kAuthEnabled) return;
  final uid = DatabaseService.instance.myId ?? 'anon';
  await NewConnections.instance.load();

  final people = await LocalCache.load('people');
  if (people is List && PeopleDirectory.instance.people.isEmpty) {
    final rows = [for (final r in people) Map<String, dynamic>.from(r as Map)];
    PeopleDirectory.instance.load(people: rows.map(personFromRow).toList(), stats: statsFromRows(rows));
  }

  final follows = await LocalCache.load('follows_$uid');
  if (follows is Map && FollowStore.instance.followingHandles.isEmpty && FollowStore.instance.followerHandles.isEmpty) {
    FollowStore.instance.load(
      following: {for (final h in (follows['following'] as List? ?? const [])) '$h'},
      followers: {for (final h in (follows['followers'] as List? ?? const [])) '$h'},
    );
  }
}

/// Step 2, in the background: fresh data from Supabase. Each piece loads on its
/// own and is saved to the phone as soon as it arrives.
Future<void> loadAppData() async {
  if (!kAuthEnabled) return;
  if (_loading) {
    _pendingReload = true;
    return;
  }
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

/// Runs one loading step. A failure is logged and does not stop the others.
Future<void> _step(String name, Future<void> Function() body) async {
  try {
    await body();
    StartupTimer.log('$name loaded');
  } catch (e) {
    debugPrint('[Swifly load] $name failed: $e');
  }
}

Future<void> _loadFromDatabase() async {
  final db = DatabaseService.instance;
  final uid = db.myId ?? 'anon';

  await Future.wait([
    _step('me', () async {
      final me = await db.fetchMe();
      if (me != null) {
        CurrentUser.name = '${me['name'] ?? me['display_name']}';
        CurrentUser.handle = '${me['handle']}';
      }
    }),
    _step('people', () async {
      final rows = await db.fetchPeople();
      PeopleDirectory.instance.load(people: rows.map(personFromRow).toList(), stats: statsFromRows(rows));
      LocalCache.save('people', rows);
      // Start downloading every profile picture now, so they are on the phone before they are shown.
      for (final r in rows) {
        AvatarCache.instance.pathFor('${r['avatar_url'] ?? ''}');
      }
    }),
    _step('posts', () async {
      final rows = await db.fetchPosts(limit: 20, offset: 0);
      PostStore.instance.merge(newPosts: rows.map(postFromRow).toList());
    }),
    _step('follows', () async {
      final f = await db.fetchFollows();
      final following = (f['following'] ?? const <String>[]).toSet();
      final followers = (f['followers'] ?? const <String>[]).toSet();
      FollowStore.instance.load(following: following, followers: followers);
      LocalCache.save('follows_$uid', {'following': following.toList(), 'followers': followers.toList()});
    }),
    _step('notifications', () async {
      final rows = await db.fetchNotifications();
      NotificationStore.instance.load(rows.map(notificationFromRow).toList());
    }),
    _step('messages', () async {
      final rows = await db.fetchMessages();
      ChatStore.instance.load(threadsFromRows(rows));
    }),
    _step('profile', () => ProfileStore.instance.loadFromDatabase()),
  ]);
}

Future<void> clearAppData() async {
  try {
    await SupabaseRealtime.stop();
  } catch (_) {}
  CurrentUser.name = 'Your Name';
  CurrentUser.handle = '@yourhandle';
  PeopleDirectory.instance.load();
  PostStore.instance.load(posts: []);
  await PostStore.instance.clearCache();
  FollowStore.instance.load();
  NotificationStore.instance.load([]);
  ChatStore.instance.reset();
  await ProfileStore.instance.clearDevice();
  await DatabaseService.instance.clearLocalMediaCache();
  await LocalCache.clear();
  await AvatarCache.instance.clear();
  NewConnections.instance.clear();
}
