# Swifly story update

## Fonts
- Every label in the app now uses Roboto (theme + default text style in lib/main.dart, constant `kAppFont`).

## Add story (lib/add_story_screen.dart)
- Pinch with two fingers to zoom the photo in/out, drag to move it, twist to rotate it.
- Text is a movable layer: drag, pinch to resize, twist to rotate, tap to edit. Aa button adds more text. Text colour + box style in the text editor.
- Animated stickers (Smile button): pulse, bounce, spin, float, wiggle, heartbeat, twinkle. Drag, resize, rotate like text.
- Location (pin button): zone/block, barangay and city, or "Use my current location" (real GPS permission + OpenStreetMap). Your last place is remembered.
- Drag any text, sticker or location onto the trash circle at the bottom to delete it.
- Stories now expire after 24 hours.

## Viewing a story
- lib/story_player_screen.dart: what other people see. Progress bar, long-press to pause, double-tap or heart button = animated hearts, quick emoji reactions, reply box.
- Open another person's profile picture (blue ring) to view their story and reply.
- A reply or reaction goes to that person's Messages with a thumbnail of the story above it.
- When someone replies to MY story: notification "replied to your story" + a message in my Messages with my story thumbnail and their reply. Tap the thumbnail to open the story.
- lib/story_viewer_screen.dart (my own story): live animated hearts when someone reacts, list of reactions and replies, tap a reply to open the chat.

## Files
New: story_models.dart, story_widgets.dart, story_player_screen.dart, story_location_sheet.dart
Changed: add_story_screen.dart, story_viewer_screen.dart, inbox_store.dart, chat_screen.dart, messages_tab.dart, notifications_tab.dart, notification_router.dart, realtime.dart, realtime_router.dart, mock_realtime.dart, mock_data.dart, location_service.dart, user_profile_screen.dart, main.dart
