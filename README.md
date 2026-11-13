# Swifly

Flutter social media app (home feed, messages, notifications, profile), connected to Supabase and built with GitHub Actions.

## 1. Supabase (one time)

1. Supabase dashboard -> SQL Editor -> New query. Paste the whole of `supabase/schema.sql` and press Run.
   It creates every table, policy, trigger, realtime channel and the avatar bucket. It is safe to run again.
2. Deploy the two Edge Functions and set their secrets (step by step in `AUTH_SETUP.md`):
   `supabase/functions/email-code-auth/index.ts` and `supabase/functions/google-oauth/index.ts`.

## 2. GitHub secrets (one time)

Repository -> Settings -> Secrets and variables -> Actions:

- `SUPABASE_URL`: Project URL, for example `https://abcd1234.supabase.co`
- `SUPABASE_PUBLISHABLE_KEY`: the publishable (anon) key

The build reads them and passes them into the app with `--dart-define`. Nothing is typed into the code.
If either secret is missing, the workflow stops with a clear message.

## 3. Termux setup

```
pkg update && pkg install -y git unzip
unzip swifly.zip -d ~/swifly
cd ~/swifly
git init && git add . && git commit -m "init"
git branch -M main
git remote add origin https://github.com/YOUR_USER/swifly.git
git push -u origin main
```

Then open the Actions tab on GitHub. The "Build Android APK" workflow produces the APK in the run's Artifacts section.

## What is connected to Supabase

- Sign up, sign in, password reset (email codes through the `email-code-auth` Edge Function)
- Profile: name, username, picture (Storage bucket `avatars`), fields with who-can-see rules
- Posts (text, Everyone / Followers audience, tagged people), likes, saves, comments and replies
- Follow / unfollow with follower and following counts
- Notifications (created by database triggers; read state is saved)
- Direct messages, reply to message, notes (24 hours)
- Hashtags (trending list is updated by the database)
- Shared profile suggestions (what other people typed for work, school, hobbies ...)
- Live updates for everything above (Supabase Realtime)

## Not connected yet

- Photo and video files in posts are not uploaded to the database yet. Posts with media show the media on the phone that made them.
- Stories and story replies stay on the phone.
- "Someone is typing" indicators stay on the phone.

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
- New activity from other people arrives through Supabase Realtime (`lib/supabase_realtime.dart`).

## Changing the database later

Every database call is in `lib/database_service.dart`. Every table, column and policy is in `supabase/schema.sql`. Live events are turned into app events in `lib/supabase_realtime.dart`.
