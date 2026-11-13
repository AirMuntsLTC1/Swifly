# Mock data in Swifly

All fake users, posts, chats, notes, stories, counts and trending tags live ONLY in `lib/mock/`.

## Turn mock data off (keeps the files)
`lib/app_config.dart` -> `const bool kUseMockData = false;`
The app then starts empty and loads everything through `DatabaseService`.

## Delete mock data for good
`python3 tools/remove_mock.py`

## Connect Supabase
1. Run `supabase/schema.sql` in the Supabase SQL editor.
2. Fill in the 8 `fetch...` methods at the bottom of `lib/database_service.dart`
   (each has an example query). They return plain rows.
3. `lib/db_mappers.dart` turns rows into Posts, Notifications, Chats... so no screen changes.
4. Fill the write methods (savePost, toggleLike, sendMessage...) at the top of the same file.
5. Live updates: in `lib/app_bootstrap.dart` `startLiveActivity()`, subscribe to Supabase realtime
   and call `Realtime.instance.publish(...)`.

Not connected yet: post photo/video URLs, and other people's stories (stay empty until added).
