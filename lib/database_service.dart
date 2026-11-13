
/// This is the ONLY file you need to edit when connecting to Firebase, Supabase, or a REST API.
/// Currently, it simulates network delays so the UI works exactly as it does now.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  // TODO: Replace these with real API calls
  Future<void> savePost(String text, String audience, List<String> taggedHandles, List<String> mediaPaths) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> toggleLike(String postId, bool isLiked) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> toggleSave(String postId, bool isSaved) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> addComment(String postId, String text) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> toggleFollow(String handle, bool isFollowing) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// Saves one profile field and who can see it.
  Future<void> saveProfileField(String key, String value, String audience) async {
    await Future.delayed(const Duration(milliseconds: 150));
    // Example: await supabase.from('profiles').update({key: value, '${key}_audience': audience}).eq('handle', kMeHandle);
  }

  /// Uploads a new profile picture from a local file path.
  Future<void> uploadAvatar(String localPath) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Example: upload the file to storage, then save its URL on the profile.
  }

  /// Values other people typed for a profile field that the built-in lists do
  /// not have (a small company, a local school ...). [category] is the
  /// SuggestKind name: company, school, jobTitle, fieldOfStudy, hobby, music,
  /// tv, movie, game, sport, place, language.
  /// Return rows like {'title': 'Acme Labs', 'subtitle': 'Lagos'}.
  Future<List<Map<String, String>>> searchSuggestions(String category, String query) async {
    await Future.delayed(const Duration(milliseconds: 120));
    // Example (Supabase):
    //   final rows = await supabase.rpc('search_profile_suggestions',
    //       params: {'p_category': category, 'p_query': query, 'p_limit': 6});
    //   return [for (final r in rows) {'title': r['title'], 'subtitle': r['subtitle'] ?? ''}];
    return <Map<String, String>>[];
  }

  /// Counts one use of a value so popular entries rise in everyone's list.
  Future<void> recordSuggestionPick(String category, String value) async {
    await Future.delayed(const Duration(milliseconds: 80));
    // Example: await supabase.rpc('record_profile_suggestion', params: {'p_category': category, 'p_value': value});
  }

  /// Loads the signed-in user's saved profile.
  /// Return one row per filled field: {'key': 'work', 'value': 'Dev at Google', 'audience': 'everyone'}.
  /// audience is onlyMe, followers or everyone. Used by ProfileStore.loadFromDatabase.
  Future<List<Map<String, String>>> fetchProfileFields() async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Example (Supabase):
    //   final rows = await supabase.from('profile_fields').select('key,value,audience').eq('user_id', uid);
    //   return [for (final r in rows) {'key': r['key'], 'value': r['value'], 'audience': r['audience']}];
    return <Map<String, String>>[];
  }

  /// Sends a direct message. [replyToId] is the message being replied to, if any.
  Future<void> sendMessage(String handle, String text, {String? replyToId, String? postId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    // Example (Supabase):
    //   await supabase.from('messages').insert({'to': handle, 'text': text, 'reply_to': replyToId, 'post_id': postId});
  }

  /// Saves my note (shown above the inbox for 24 hours). Empty text deletes it.
  Future<void> saveNote(String text) async {
    await Future.delayed(const Duration(milliseconds: 150));
    // Example: await supabase.from('notes').upsert({'user_id': uid, 'text': text});
  }

  // ---------------------------------------------------------------------------
  // READ METHODS. These are the only functions you fill in to go live.
  // Each returns plain rows (Map). app_bootstrap.dart + db_mappers.dart turn the
  // rows into the objects the screens already use, so the design never changes.
  // Table and column names match supabase/schema.sql.
  // Return an empty list / null while a table is not connected yet.
  // ---------------------------------------------------------------------------

  /// {'display_name': 'Your Name', 'username': 'you'} for the signed-in user, or null.
  Future<Map<String, dynamic>?> fetchMe() async {
    // Example: final r = await supabase.from('profiles').select('display_name,username').eq('id', uid).single();
    return null;
  }

  /// Rows: {username, display_name, followers_count, following_count} (handle/name also work)
  Future<List<Map<String, dynamic>>> fetchPeople() async {
    // Example: return List<Map<String, dynamic>>.from(await supabase.from('profiles').select('username,display_name,followers_count,following_count'));
    return <Map<String, dynamic>>[];
  }

  /// Hashtag names without the #, most popular first.
  Future<List<String>> fetchTrendingTags() async {
    // Example: final rows = await supabase.from('trending_tags').select('tag').limit(12);
    return <String>[];
  }

  /// Rows: {id, author_name, author_handle, text, audience, tagged_handles (list),
  /// created_at, likes, saves, shares, liked, saved,
  /// comments: [{id, name, text, created_at, replies: [same shape]}]}
  Future<List<Map<String, dynamic>>> fetchPosts() async {
    // Example: await supabase.from('posts_feed').select().order('created_at', ascending: false);
    return <Map<String, dynamic>>[];
  }

  /// {'following': ['@a', ...], 'followers': ['@b', ...]}
  Future<Map<String, List<String>>> fetchFollows() async {
    // Example: read the follows table where follower = me / followee = me.
    return <String, List<String>>{'following': <String>[], 'followers': <String>[]};
  }

  /// Rows: {id, type, actor_name, actor_handle, post_id, comment_id, emoji, preview, created_at, read}
  /// type is one of: like, comment, reply, save, follow, message, storyReact, tag, storyReply.
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    return <Map<String, dynamic>>[];
  }

  /// Rows: {id, peer_handle, text, from_me, created_at}
  Future<List<Map<String, dynamic>>> fetchMessages() async {
    return <Map<String, dynamic>>[];
  }

  /// Rows: {handle, text, created_at} (notes of people you follow).
  Future<List<Map<String, dynamic>>> fetchNotes() async {
    return <Map<String, dynamic>>[];
  }
}
