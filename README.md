# Swifly

Flutter social media app (home feed, messages, notifications, profile) built with GitHub Actions.

## Termux setup
pkg update && pkg install -y git unzip
unzip swifly.zip -d ~/swifly
cd ~/swifly
git init && git add . && git commit -m "init"
git branch -M main
git remote add origin https://github.com/YOUR_USER/swifly.git
git push -u origin main

Then open the Actions tab on GitHub. The "Build Android APK" workflow produces
the APK in the run's Artifacts section.

## Photos and videos (PHP pipeline, connected through C++)

Posts can hold photos and videos together (up to 10). The work is split so the screens only show things:

- **PHP does the media work** (`cpp/php/`, one job per file):
  - `photo_processor.php`: fixes phone rotation, makes the cached photo (max 1440 px) and a 480 px thumbnail (needs GD in the PHP runtime; without it the photo is copied).
  - `video_processor.php`: reads length and size from the MP4 header, keeps a local copy, makes the thumbnail (ffmpeg if the app ships one, otherwise the picker's preview picture).
  - `cache_store.php`: the local cache (`originals/`, `thumbs/`, `index.json`). The same file is never processed twice; the oldest items are removed when the cache passes 400 MB.
  - `common.php`, `main.php`: shared helpers and the entry point.
- **C++ connects it** (`cpp/media_bridge.cpp`): carries the PHP files inside `libswifly_core.so`, unpacks them on start, runs them with the bundled PHP runtime (`libphp_cli.so`) and returns the result. If there is no PHP runtime, a small built-in fallback caches the file so the app keeps working (no resizing, no video thumbnails).
- **Dart only calls C++ and draws** (`lib/media/`): `media_pipeline.dart` (the C++ call), `photo_tile.dart`, `video_tile.dart`, `post_media_view.dart`, `media_thumb.dart`, `preview_image.dart`, and `video_autoplay.dart`.

How it behaves:
- Picking media in the composer starts PHP at once, while you type. Tapping Post shows the post immediately; items PHP has not finished switch to the cached copy when ready.
- A video plays (muted, looping) when at least 60% of it is on screen and it is the most visible one. Otherwise it pauses, and 2 seconds later its player is released so nothing keeps decoding off screen. Tap a video to turn sound on or off.
- Thumbnails come from the cache and show before any player starts.

PHP runtime: `tools/build_php_android.sh` builds it in the GitHub workflow (cached after the first run) and puts it in the APK. If that step fails, the APK still builds and the C++ fallback is used. `MediaPipeline.instance.phpRuntimeActive` tells you which one is running. To add video thumbnails by ffmpeg later, ship an ffmpeg binary named `libffmpeg_cli.so` next to `libphp_cli.so` (`android/app/src/main/jniLibs/arm64-v8a/`).

## Notifications

- Red unread count on the bell icon (Notifications tab).
- Popup card at the top when a new notification arrives. Tap it to open, swipe up to dismiss.
- Tapping a like, save, comment or reply opens the post. The matching comment or reply scrolls into view and flashes yellow.
- Follow opens the person's profile. Message opens the chat. Story reaction opens your story.
- `lib/inbox_store.dart` has `LiveEvents.demo`. It simulates other people's activity every 15 seconds so you can test without a server. Set it to `false` when a real backend sends these events.

## Realtime and test data

All changes from other people go through one stream, `Realtime.instance` in `lib/realtime.dart`. Every screen listens to the stores, so a like, comment, typing indicator, follow, or message updates everywhere at once.

### Test data (remove when going live)
- `lib/app_config.dart`: `kUseMockData` switches sample data on or off.
- `lib/mock_data.dart`: all sample posts, notifications, chats, story, and followers.
- `lib/mock_realtime.dart`: simulated activity (likes, comments, typing, follows, messages).
- Also sample data (not yet switched off by `kUseMockData`): `kPeople` in `lib/tag_friends_screen.dart`, the follower/following counts in `lib/discover_panel.dart`, `kPeopleStats` in `lib/user_profile_screen.dart`, and the profile stats in `lib/home_screen.dart`.

### Connecting the real database
1. Set `kUseMockData = false` in `lib/app_config.dart`.
2. Delete `lib/mock_data.dart` and `lib/mock_realtime.dart`.
3. Load real posts, people, and notifications at startup, calling `PostStore.instance.load(...)`, `NotificationStore.instance.load(...)`, and so on.
4. In `lib/database_service.dart`, replace each simulated method with a real call.
5. Subscribe to your database's realtime channel and call `Realtime.instance.publish(...)` with the matching event (for example `CommentAddedEvent`). The screens need no other changes.

## Follow system (Follow / Following / Follow back)

There are no friend requests. Everything is follow-based.

- `lib/follow_store.dart`: the only place follow state lives. `FollowStore.instance.load(...)` sets the lists, `follow` and `unfollow` change them (and call the database), and `applyIncomingFollow` / `applyIncomingUnfollow` handle changes from other people. `personFor(handle)` looks up a person's name (sample data for now).
- `lib/follow_button.dart`: the only follow button in the app. Every screen uses it, so the labels are the same everywhere: Follow, Follow back, or Following. Tapping Following asks for confirmation before unfollowing.
- Followers and Following lists come from `FollowStore` (`lib/connections_screen.dart`).

### Changing follow to a real database later
1. In `lib/follow_store.dart`, load the lists from the database in `load(...)`.
2. In `lib/database_service.dart`, implement `toggleFollow` (it is already called by `follow` and `unfollow`).
3. When someone follows or unfollows you, publish `FollowedEvent` or `UnfollowedEvent` to `Realtime`. The rest of the app updates by itself.
4. Replace the body of `personFor` with a lookup of real user data.

## Profile and Edit profile

- `lib/profile_store.dart`: every profile field, its audience (only me, followers, everyone), and the field list. Add a field by adding one line to `kProfileSections`.
- `lib/edit_profile_screen.dart`: Edit profile (photo, sections, field editor). Photo picking uses the same picker as the composer.
- `lib/profile_details_section.dart`: Personal details and Contact info on your profile.
- C++ (`cpp/swifly_core.cpp`): `swifly_age_years` calculates age from the birthday, and `swifly_can_see` applies the privacy rule. Both have Dart fallbacks in `lib/native_bridge.dart`.
- Saving: `lib/database_service.dart` has `saveProfileField` and `uploadAvatar` to connect to your database.

## Profile suggestions (search as you type)

Work, school, hobbies, music, TV, movies, games, sports, places, languages and the two city fields search while you type.
Type "J" and every name starting with J is listed. Keep typing and the list narrows until yours appears. Tap a row to pick it.
Anything missing from the list can be saved as typed ("Add ...").

- `lib/suggest_data.dart`: the built-in lists, one entry per line as `Title|Subtitle`. Most popular first. Add or remove lines freely.
- `lib/suggest_engine.dart`: `SuggestService` (search, recent picks, merge with database results) and the helpers that join several picks or combine "Position at Company".
- `lib/suggest_picker.dart`: the search box, the live list with the matched letters in bold, and the chips for fields that take several picks.
- `lib/profile_store.dart`: each field says what it searches in `kProfileSections` (`suggest:`, `secondary:`, `multi:`). Email, phone number, website and social handle are checked before saving.
- C++ (`cpp/swifly_core.cpp`): `swifly_suggest_search` ranks the matches (exact, starts with, a later word starts with, contains, small typos). `NativeCore.suggestSearch` has the same ranking in Dart as a fallback.
- Tests: `flutter test test/suggest_engine_test.dart`.

How several picks are stored: Hobbies, Music, TV shows, Movies, Games, Sports, Places and Languages are saved as one text value joined with " • ". Work and School are saved as "Position at Company".

### Connecting shared suggestions (database)
`DatabaseService.searchSuggestions` and `recordSuggestionPick` are stubs. When they are connected, things other people typed (a small company, a local school) start appearing for everyone, and popular ones rise. Example for Supabase:

```sql
create extension if not exists pg_trgm;
create table profile_suggestions (
  category text not null,
  title text not null,
  subtitle text not null default '',
  uses int not null default 1,
  primary key (category, title)
);
create index on profile_suggestions using gin (title gin_trgm_ops);

create function search_profile_suggestions(p_category text, p_query text, p_limit int default 6)
returns table(title text, subtitle text) language sql stable as $$
  select title, subtitle from profile_suggestions
  where category = p_category and title ilike p_query || '%'
  order by uses desc limit p_limit;
$$;

create function record_profile_suggestion(p_category text, p_value text)
returns void language sql as $$
  insert into profile_suggestions (category, title) values (p_category, p_value)
  on conflict (category, title) do update set uses = profile_suggestions.uses + 1;
$$;
```

## Connecting the profile to a real database

Everything the person fills in on Edit profile goes through two methods in `lib/database_service.dart`, so this is the only file to change:

- `saveProfileField(key, value, audience)`: called on every save (audience is `onlyMe`, `followers` or `everyone`).
- `fetchProfileFields()`: returns the saved rows. Call `ProfileStore.instance.loadFromDatabase()` once after sign-in.
- `searchSuggestions` and `recordSuggestionPick`: optional shared suggestions (see above).

A new profile field needs one line in `kProfileSections` (`lib/profile_store.dart`). No database change is needed, because fields are rows, not columns:

```sql
create table profile_fields (
  user_id uuid not null references auth.users on delete cascade,
  key text not null,
  value text not null,
  audience text not null default 'everyone' check (audience in ('onlyMe','followers','everyone')),
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);
alter table profile_fields enable row level security;

-- the owner can do everything
create policy "owner all" on profile_fields for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- others see 'everyone' fields, and 'followers' fields if they follow the owner
-- (adjust the follows table and column names to yours)
create policy "viewers read" on profile_fields for select using (
  audience = 'everyone'
  or (audience = 'followers' and exists (
        select 1 from follows f where f.follower_id = auth.uid() and f.following_id = profile_fields.user_id))
);
```

Supabase calls to put in the two methods:

```dart
// saveProfileField
await supabase.from('profile_fields').upsert({
  'user_id': supabase.auth.currentUser!.id, 'key': key, 'value': value, 'audience': audience,
});
// fetchProfileFields
final rows = await supabase.from('profile_fields').select('key,value,audience')
    .eq('user_id', supabase.auth.currentUser!.id);
```
An empty value should delete the row (or save an empty string), so a cleared field disappears from the profile.
