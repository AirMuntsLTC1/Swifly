# Swifly update: real profile, real location, real logos, fits every phone

## Real location (profile > Update profile > Current city / Hometown / Places)
- "Use my current location" button: shows the real Android "Allow location" popup, reads GPS, turns it into a city (OpenStreetMap).
- Type any city in the world: live results from OpenStreetMap with a country flag.
- If location is off or blocked, a message with a Settings button appears.
- Files: lib/location_service.dart, lib/suggest_picker.dart, lib/suggest_engine.dart

## Real work / school logos
- Work and School search real companies, schools, universities and colleges worldwide (Wikidata) and show their real logo.
- Popular ones (Google, Meta, MTN, Harvard, UNILAG, Oxford ...) show their logo instantly. Unknown ones get coloured initials.
- Profile shows "Works at ...", "Studied ... at ...", "Lives in ...", "From ..." with the logo / pin. Tap a row to edit it.
- Files: lib/logo_service.dart, lib/profile_details_section.dart

## Profile is saved on the phone
- City, hometown, work, school, hobbies, bio, picture now stay after you close the app (lib/profile_store.dart).

## Real Add story
- Add story (profile and + menu) opens a real story maker: text, colour, photo. Tap your avatar to view or delete it.
- Files: lib/add_story_screen.dart, lib/story_viewer_screen.dart, lib/inbox_store.dart

## Fits any phone
- lib/responsive.dart scales sizes to the screen width/height and limits width on tablets.
- Fixed: profile tab, other-user profile, suggestion cards, emoji pickers, + menu, story reactions list.

## Android permissions (added by the GitHub workflow)
- INTERNET, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION (.github/workflows/build-apk.yml)
- New package: geolocator (pubspec.yaml)
