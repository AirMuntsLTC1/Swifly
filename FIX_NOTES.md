# Swifly fix round: what changed

## Startup and login speed
- splash_screen.dart: no longer waits for every database query. It starts Supabase
  (8 s limit), shows the saved feed and saved people/follows straight away, then opens
  the first screen. Fresh data loads in the background.
- auth/auth_flow.dart: completeSignIn opens Home at once and loads data in the background.
  Before, it waited for all seven queries, which is why login took about a minute.
- auth_service.dart: restores the session with recoverSession (no extra network refresh).
  signedIn never throws. Usernames are compared in lower case.
- app_bootstrap.dart: each query loads separately and logs its own failure. Results are
  saved to the phone (local_cache.dart) so the next start is instant.
- database_service.dart: posts load their media in parallel. Messages look up all
  people in one query instead of one per message. Story photos load in parallel.

## Profile pictures and cache
- avatar_cache.dart (new): each picture is saved on the phone once, under a stable file
  name. Later views read the file with no network. Avatars are prefetched when people load.
- dm_theme.dart (DmAvatar) and edit_profile_screen.dart use the cache.

## Suggestions, Discover and search
- follow_store.dart: suggestedPeople() returns only people you do not follow and who do
  not follow you. Suggestions, Discover, the home strip and the profile strip all use it.
- discover_panel.dart: search queries the whole database (not just the first 500
  people) and never returns your own account.
- person_row.dart (new): one row layout for people lists. The name column is Expanded
  with ellipsis, so long names no longer squeeze into a narrow column.

## Other people's profiles
- user_profile_screen.dart: shows that person's posts, real follower and following
  counts from the database, and suggestions that exclude people you already follow.
- connections_screen.dart: another person's Followers/Following now load from the
  database for that person. Before, they always showed your own (often empty) lists.

## Verify on the device
1. Cold start with a saved session: the feed appears at once.
2. Sign in: Home opens within a second or two of the server answering.
3. Profile pictures appear once, and show again instantly after restarting.
4. Suggestions and Discover list nobody you follow or who follows you.
5. Search finds others, never your own account.
6. Open someone's profile: posts, Followers and Following show real numbers.

## Round 2

### Personal details (audience rules)
- Other people's details now load from the database (fetchProfileFieldsOf). The
  database applies Only me / Followers / Everyone, and the app checks again on the device.
- Their profile shows those details read-only, with the same layout as your own.
- Your own profile shows the audience next to each field, e.g. "Current city · Only me".
- Age is calculated from each field's own birthday, so it is right for other people too.

### Followers and Following taps
- pushOnce no longer drops taps made within 350 ms of an earlier push. It only blocks
  opening the same screen twice. This is why several taps were needed.
- Another person's lists are prefetched when their profile opens, and a list
  opened again shows at once while it refreshes.

### Follow back showing "Follow"
- FollowStore keeps your pending change until the server confirms it, so a late
  reload cannot undo it.
- The follow lists are reloaded from the database whenever they open, so labels
  match the server.
- A failed follow or unfollow is undone and the reason is shown, instead of failing silently.
- No follow button is shown on your own account.

### Posts
- Your own profile and other profiles use the same post card (picture on top,
  text, then likes, comments and time), taken from the screenshot.

## Round 3: pictures, schools near you, red places

### Schools
- When the school field opens, the phone's location is requested. Schools within
  about 15 km are listed under "Schools near <city>", with logos from Wikidata
  (where Wikidata has one) and a school icon otherwise. The list is saved on the
  phone for 7 days.

### Pictures (no API key needed except as noted)
- Music: artist search and album artwork from iTunes (no key).
- Sports: team badge or jersey, and athlete photo, from TheSportsDB with the
  public key "3". Athlete rows show their team as the subtitle.
- Hobbies, movies, TV, games: Wikipedia thumbnails and search (no key).
- Pictures are downloaded once and kept on the phone. Rows without a picture show a Lucide icon.

### Places
- Every location icon is a red Lucide map pin (kPlaceRed), in the picker, the
  profile and "Use my current location".

### Limits
- Sports search by exact name only (free TheSportsDB tier). Typing part of a name
  finds Wikipedia matches, not every team or athlete.
- Hobby pictures come from Wikipedia and may be a generic image or none.
- School logos only appear for schools that have a logo on Wikidata.

## Round 4: suggestions and chat counts

- Every "Suggestions People" list now uses one rule: people you do not follow and
  who do not follow you. This covers Home, Messages, Discover, See all, and profile
  suggestions. The Messages list used to hide only people you follow, so follow-backs still appeared.
- The chat screen shows "N followers · N following" under the username, both in the
  empty conversation and in the header. The counts come from the database and refresh when you follow or unfollow.
