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

