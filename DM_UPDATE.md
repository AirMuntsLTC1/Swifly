# Swifly Messages update (Instagram-style direct messages)

## Inbox (lib/messages_tab.dart)
- Header with back arrow, your username, menu (mark all read, dark/light) and compose.
- Search: finds chats and other people (ranked by the C++ core).
- Notes row: "Your note" (tap the bubble to write/delete a note, 60 chars, lasts 24 h);
  tap your picture to add a story (or view it). Friends' notes show above their picture;
  a ring means they have a story. Tap a note to reply, tap the picture to watch the story.
- Chips: Filters, Primary, Requests (count), General.
- Unread: bold name + preview, blue dot, red count on the Messages icon in the top bar.
- Long-press a chat: Accept request, Mark as read/unread, View profile, Delete chat.
- Accounts to follow at the bottom, "See all" opens the full list. People who follow you come first.

## Which tab a chat goes to (swifly_dm_bucket in C++)
- Requests: you do not follow them, you never replied, you did not press Accept.
- General: nothing new for 7+ days and nothing unread.
- Primary: everything else. Following someone, replying, or Accept moves a request to Primary.

## Filters
Unread, Unanswered (their message is last), Story replies, People you follow, People who follow you.
Several can be on at once (a chat must match all of them).

## Chat (lib/chat_screen.dart)
- Long-press a message: emoji reactions, Reply, Copy, Unsend (your own).
- Or drag a message to the right to reply. Double-tap = heart.
- The reply bar above the composer shows the small profile circle, "Replying to ..." and the message.
- Sent replies show the quoted message above yours; tap the quote to jump to the original.
- Message requests show Accept / Delete instead of the composer.
- Empty composer shows a heart that sends ❤️.

## C++ (cpp/swifly_core.cpp, bound in lib/native_bridge.dart, Dart fallback for each)
swifly_dm_bucket, swifly_dm_filter_pass, swifly_dm_sort_threads, swifly_dm_time_label,
swifly_dm_clip, swifly_dm_rank_people. Test: test/dm_core_test.dart.

## Connect the database later
DatabaseService.sendMessage and DatabaseService.saveNote are the two new stubs.
ChatStore.load / receive and NoteStore.load / applyIncoming take the real data.

## Changed / new files
New: dm_theme.dart, dm_sheets.dart, dm_people_screens.dart
Changed: messages_tab.dart, chat_screen.dart, inbox_store.dart, home_screen.dart, native_bridge.dart,
database_service.dart, realtime.dart, realtime_router.dart, mock_data.dart, mock_realtime.dart,
cpp/swifly_core.cpp


