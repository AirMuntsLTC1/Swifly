import 'media/media_item.dart';
import 'story_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Every read and write the app makes to Supabase goes through this file.
/// Tables, columns, policies and triggers: supabase/schema.sql.
///
/// Read methods return plain rows (Maps). db_mappers.dart turns them into the
/// objects the screens use, so no screen needs to know about Supabase.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// True when the value is a database id. Ids made on the phone before the
  /// server answered (for example "p3") are not, so they are not sent.
  static bool isUuid(String? value) => value != null && _uuidPattern.hasMatch(value);

  SupabaseClient get _db => Supabase.instance.client;

  /// The signed-in user's id, or null before sign in.
  String? get myId => kAuthEnabled ? _db.auth.currentUser?.id : null;

  String _requireMe() {
    final id = myId;
    if (id == null) throw StateError('Not signed in.');
    return id;
  }

  final Map<String, _Who> _byId = {};
  final Map<String, String> _idByUsername = {};

  Future<_Who> _who(String id) async {
    final cached = _byId[id];
    if (cached != null) return cached;
    final row = await _db
        .from('profiles')
        .select('id,username,display_name,avatar_url')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return _Who(id: id, username: '', name: '');
    final who = _Who.fromRow(Map<String, dynamic>.from(row));
    _byId[id] = who;
    _idByUsername[who.username] = id;
    return who;
  }

  /// '@wilme' -> the profile id of that account.
  Future<String> _idForHandle(String handle) async {
    final username = handle.replaceFirst('@', '').trim().toLowerCase();
    final cached = _idByUsername[username];
    if (cached != null) return cached;
    final row = await _db.from('profiles').select('id').eq('username', username).single();
    final id = '${row['id']}';
    _idByUsername[username] = id;
    return id;
  }

  /// Name and @handle of a person by user id. Used by the live listener.
  Future<Map<String, String>> personById(String id) async {
    final who = await _who(id);
    return {'name': who.name, 'handle': who.handle};
  }

  /// Text of one message (used to show the quote of a reply).
  Future<String> messageText(String id) async {
    if (!isUuid(id)) return '';
    final row = await _db.from('messages').select('text').eq('id', id).maybeSingle();
    return row == null ? '' : '${row['text']}';
  }

  // ---------------------------------------------------------------------------
  // WRITE METHODS
  // ---------------------------------------------------------------------------

  /// Saves a post and returns its database id. Photos and videos are not
  /// uploaded yet, so [mediaPaths] stay on this phone for now.
  /// Saves a post with its photos and videos. Each file goes to the "post-media"
  /// bucket and a row goes to post_media. If an upload fails, the post is
  /// removed again, so nobody sees a post with missing media.
  Future<String?> savePost(String text, String audience, List<String> taggedHandles, List<MediaItem> media) async {
    final me = _requireMe();
    final row = await _db.from('posts').insert({
      'author_id': me,
      'text': text,
      'audience': audience == 'Followers' ? 'Followers' : 'Everyone',
      'tagged_handles': taggedHandles,
    }).select('id').single();
    final postId = '${row['id']}';
    try {
      for (var i = 0; i < media.length; i++) {
        final item = media[i];
        await _waitForProcessing(item);
        final mainPath = '$me/$postId/$i.${_extOf(item.path, item.isVideo ? 'mp4' : 'jpg')}';
        await _uploadFile('post-media', mainPath, item.path);

        String? thumbPath;
        final thumb = item.thumbPath;
        if (thumb != null && thumb.isNotEmpty && File(thumb).existsSync()) {
          thumbPath = '$me/$postId/thumb_$i.${_extOf(thumb, 'jpg')}';
          await _uploadFile('post-media', thumbPath, thumb);
        }

        await _db.from('post_media').insert({
          'post_id': postId,
          'position': i,
          'kind': item.isVideo ? 'video' : 'photo',
          'storage_path': mainPath,
          'thumb_path': thumbPath,
          'width': item.width,
          'height': item.height,
          'duration_ms': item.durationMs,
          'engine': item.engine,
        });
      }
    } catch (e) {
      await _db.from('posts').delete().eq('id', postId);
      rethrow;
    }
    return postId;
  }

  /// The pipeline may still be preparing a video or photo. Wait for it (up to a minute).
  Future<void> _waitForProcessing(MediaItem item) async {
    var waited = 0;
    while (item.processing && waited < 60000) {
      await Future.delayed(const Duration(milliseconds: 250));
      waited += 250;
    }
  }

  Future<void> _uploadFile(String bucket, String storagePath, String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('A photo or video could not be found on this phone. Try adding it again.');
    }
    await _db.storage.from(bucket).upload(storagePath, file, fileOptions: const FileOptions(upsert: true));
  }

  static String _extOf(String path, String fallback) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot < path.lastIndexOf('/')) return fallback;
    return path.substring(dot + 1).toLowerCase();
  }

  Future<void> toggleLike(String postId, bool isLiked) async {
    if (!isUuid(postId)) throw StateError('This post is still being saved.');
    final me = _requireMe();
    if (isLiked) {
      await _db.from('post_likes').upsert(
        {'user_id': me, 'post_id': postId},
        onConflict: 'user_id,post_id',
        ignoreDuplicates: true,
      );
    } else {
      await _db.from('post_likes').delete().eq('user_id', me).eq('post_id', postId);
    }
  }

  Future<void> toggleSave(String postId, bool isSaved) async {
    if (!isUuid(postId)) throw StateError('This post is still being saved.');
    final me = _requireMe();
    if (isSaved) {
      await _db.from('post_saves').upsert(
        {'user_id': me, 'post_id': postId},
        onConflict: 'user_id,post_id',
        ignoreDuplicates: true,
      );
    } else {
      await _db.from('post_saves').delete().eq('user_id', me).eq('post_id', postId);
    }
  }

  /// Adds a comment, or a reply when [parentId] is given. Returns the new id.
  Future<String> addComment(String postId, String text, {String? parentId}) async {
    if (!isUuid(postId) || (parentId != null && !isUuid(parentId))) {
      throw StateError('This post or comment is still being saved.');
    }
    final row = await _db.from('comments').insert({
      'post_id': postId,
      'author_id': _requireMe(),
      'text': text,
      if (parentId != null) 'parent_id': parentId,
    }).select('id').single();
    return '${row['id']}';
  }

  /// Adds a share count to a post (the number of people it was sent to).
  Future<void> registerShare(String postId, int count) async {
    if (!isUuid(postId) || count <= 0) return;
    await _db.rpc('increment_post_shares', params: {'p_post_id': postId, 'p_count': count});
  }

  Future<void> toggleFollow(String handle, bool isFollowing) async {
    final me = _requireMe();
    final target = await _idForHandle(handle);
    if (isFollowing) {
      await _db.from('follows').upsert(
        {'follower': me, 'followee': target},
        onConflict: 'follower,followee',
        ignoreDuplicates: true,
      );
    } else {
      await _db.from('follows').delete().eq('follower', me).eq('followee', target);
    }
  }

  /// Saves one profile field and who can see it. An empty value removes the field.
  Future<void> saveProfileField(String key, String value, String audience) async {
    final me = _requireMe();
    if (value.trim().isEmpty) {
      await _db.from('profile_fields').delete().eq('user_id', me).eq('key', key);
      return;
    }
    await _db.from('profile_fields').upsert(
      {'user_id': me, 'key': key, 'value': value.trim(), 'audience': audience, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      onConflict: 'user_id,key',
    );
  }

  /// Uploads a new profile picture to the "avatars" bucket and saves its link.
  Future<String> uploadAvatar(String localPath) async {
    final me = _requireMe();
    final dot = localPath.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : localPath.substring(dot + 1).toLowerCase();
    final path = '$me/avatar.$ext';
    final storage = _db.storage.from('avatars');
    await storage.upload(path, File(localPath), fileOptions: const FileOptions(upsert: true));
    final url = storage.getPublicUrl(path);
    final finalUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    await _db.from('profiles').update({
      'avatar_url': finalUrl,
    }).eq('id', me);
    return finalUrl;
  }

  /// Values other people typed for a profile field that the built-in lists do
  /// not have. [category] is the SuggestKind name (company, school, hobby ...).
  Future<List<Map<String, String>>> searchSuggestions(String category, String query) async {
    final rows = await _db.rpc('search_profile_suggestions', params: {
      'p_category': category,
      'p_query': query,
      'p_limit': 6,
    });
    return [
      for (final r in (rows as List))
        {'title': '${r['title'] ?? ''}', 'subtitle': '${r['subtitle'] ?? ''}'},
    ];
  }

  /// Counts one use of a value so popular entries rise in everyone's list.
  Future<void> recordSuggestionPick(String category, String value) async {
    await _db.rpc('record_profile_suggestion', params: {'p_category': category, 'p_value': value});
  }

  /// Sends a direct message. [replyToId] is the message being replied to, if any.
  Future<void> sendMessage(String handle, String text, {String? replyToId, String? postId}) async {
    final me = _requireMe();
    final to = await _idForHandle(handle);
    await _db.from('messages').insert({
      'sender': me,
      'recipient': to,
      'text': text,
      if (isUuid(replyToId)) 'reply_to_id': replyToId,
      if (isUuid(postId)) 'post_id': postId,
    });
  }

  /// Saves my note (shown above the inbox for 24 hours). Empty text deletes it.
  Future<void> saveNote(String text) async {
    final me = _requireMe();
    final t = text.trim();
    if (t.isEmpty) {
      await _db.from('notes').delete().eq('user_id', me);
      return;
    }
    await _db.from('notes').upsert(
      {'user_id': me, 'text': t, 'created_at': DateTime.now().toUtc().toIso8601String()},
      onConflict: 'user_id',
    );
  }

  /// Marks one notification read or unread. Local-only ids are skipped.
  Future<void> setNotificationRead(String id, bool read) async {
    if (!isUuid(id)) return;
    await _db.from('notifications').update({'read': read}).eq('id', id).eq('user_id', _requireMe());
  }

  Future<void> markAllNotificationsRead() async {
    await _db.from('notifications').update({'read': true}).eq('user_id', _requireMe()).eq('read', false);
  }

  Future<void> deleteNotification(String id) async {
    if (!isUuid(id)) return;
    await _db.from('notifications').delete().eq('id', id).eq('user_id', _requireMe());
  }

  // ---------------------------------------------------------------------------
  // READ METHODS
  // ---------------------------------------------------------------------------

  /// {'name': 'Your Name', 'display_name': ..., 'username': 'you', 'handle': '@you'} or null.
  Future<Map<String, dynamic>?> fetchMe() async {
    final me = myId;
    if (me == null) return null;
    final who = await _who(me);
    return {
      'name': who.name,
      'display_name': who.name,
      'username': who.username,
      'handle': who.handle,
      'avatar_url': who.avatarUrl,
    };
  }

  /// Rows: {name, handle, followers_count, following_count}, biggest first.
  Future<List<Map<String, dynamic>>> fetchPeople() async {
    final rows = await _db
        .from('profiles')
        .select('username,display_name,followers_count,following_count')
        .order('followers_count', ascending: false)
        .limit(500);
    return [
      for (final r in rows)
        {
          'name': _Who.fromRow(Map<String, dynamic>.from(r)).name,
          'handle': _Who.fromRow(Map<String, dynamic>.from(r)).handle,
          'followers_count': r['followers_count'] ?? 0,
          'following_count': r['following_count'] ?? 0,
        },
    ];
  }

  /// Hashtag names without the #, most popular first.
  Future<List<String>> fetchTrendingTags() async {
    final rows = await _db.from('trending_tags').select('tag').order('uses', ascending: false).limit(12);
    return [for (final r in rows) '${r['tag']}'];
  }

  /// Posts you are allowed to see (the database decides), newest first, with
  /// comments, replies, and whether you liked or saved each one.
  Future<List<Map<String, dynamic>>> fetchPosts({int limit = 4, int offset = 0}) async {
    final me = _requireMe();
    final postRows = await _db
        .from('posts')
        .select('id,text,audience,tagged_handles,likes,saves,shares,created_at,author:profiles!author_id(username,display_name)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    if (postRows.isEmpty) return <Map<String, dynamic>>[];

    final ids = [for (final r in postRows) '${r['id']}'];

    final commentRows = await _db
        .from('comments')
        .select('id,post_id,parent_id,text,created_at,author:profiles!author_id(username,display_name)')
        .inFilter('post_id', ids)
        .order('created_at', ascending: true);
    final likedRows = await _db.from('post_likes').select('post_id').eq('user_id', me).inFilter('post_id', ids);
    final savedRows = await _db.from('post_saves').select('post_id').eq('user_id', me).inFilter('post_id', ids);

    final liked = {for (final r in likedRows) '${r['post_id']}'};
    final saved = {for (final r in savedRows) '${r['post_id']}'};

    // Build every comment first, then attach replies to their parent.
    final byId = <String, Map<String, dynamic>>{};
    for (final r in commentRows) {
      final author = _Who.fromRow(_embedded(r['author']));
      byId['${r['id']}'] = <String, dynamic>{
        'id': '${r['id']}',
        'name': author.name,
        'text': '${r['text']}',
        'created_at': '${r['created_at']}',
        'replies': <Map<String, dynamic>>[],
      };
    }
    final topLevel = <String, List<Map<String, dynamic>>>{};
    for (final r in commentRows) {
      final node = byId['${r['id']}']!;
      final parent = r['parent_id'];
      if (parent == null) {
        topLevel.putIfAbsent('${r['post_id']}', () => <Map<String, dynamic>>[]).add(node);
      } else {
        final p = byId['$parent'];
        if (p != null) (p['replies'] as List<Map<String, dynamic>>).add(node);
      }
    }

    final mediaRows = await _db
        .from('post_media')
        .select('post_id,position,kind,storage_path,thumb_path,width,height,duration_ms,engine')
        .inFilter('post_id', ids)
        .order('position', ascending: true);
    final mediaByPost = <String, List<Map<String, dynamic>>>{};
    for (final m in mediaRows) {
      final local = await _cachedFile('post-media', '${m['storage_path']}');
      if (local == null) continue; // could not download: skip it rather than show a broken tile
      final thumbPath = m['thumb_path'];
      final thumb = thumbPath == null ? null : await _cachedFile('post-media', '$thumbPath');
      mediaByPost.putIfAbsent('${m['post_id']}', () => <Map<String, dynamic>>[]).add({
        'kind': m['kind'],
        'path': local,
        'thumb': thumb,
        'width': m['width'],
        'height': m['height'],
        'duration_ms': m['duration_ms'],
        'engine': m['engine'] ?? '',
      });
    }

    return [
      for (final r in postRows)
        _postMap(
          r,
          liked: liked.contains('${r['id']}'),
          saved: saved.contains('${r['id']}'),
          comments: topLevel['${r['id']}'] ?? <Map<String, dynamic>>[],
          media: mediaByPost['${r['id']}'] ?? <Map<String, dynamic>>[],
        ),
    ];
  }

  Map<String, dynamic> _postMap(
    Map<String, dynamic> r, {
    required bool liked,
    required bool saved,
    required List<Map<String, dynamic>> comments,
    List<Map<String, dynamic>> media = const [],
  }) {
    final author = _Who.fromRow(_embedded(r['author']));
    return <String, dynamic>{
      'id': '${r['id']}',
      'author_name': author.name,
      'author_handle': author.handle,
      'text': '${r['text']}',
      'audience': '${r['audience']}',
      'tagged_handles': r['tagged_handles'] ?? <String>[],
      'created_at': '${r['created_at']}',
      'likes': r['likes'] ?? 0,
      'saves': r['saves'] ?? 0,
      'shares': r['shares'] ?? 0,
      'liked': liked,
      'saved': saved,
      'comments': comments,
      'media': media,
    };
  }

  /// {'following': ['@a', ...], 'followers': ['@b', ...]}
  Future<Map<String, List<String>>> fetchFollows() async {
    final me = _requireMe();
    final outRows = await _db.from('follows').select('followee,target:profiles!followee(username)').eq('follower', me);
    final inRows = await _db.from('follows').select('follower,source:profiles!follower(username)').eq('followee', me);
    return {
      'following': [for (final r in outRows) _handleOf(r['target'])],
      'followers': [for (final r in inRows) _handleOf(r['source'])],
    };
  }

  /// Rows: {id, type, actor_name, actor_handle, post_id, comment_id, emoji, preview, created_at, read}
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final rows = await _db
        .from('notifications')
        .select('*')
        .eq('user_id', _requireMe())
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// Rows: {id, peer_handle, text, from_me, created_at}, oldest first.
  Future<List<Map<String, dynamic>>> fetchMessages() async {
    final me = _requireMe();
    final rows = await _db
        .from('messages')
        .select('''
          id, sender, recipient, text, reply_to_id, post_id, created_at,
          post:posts!post_id(
            id, text,
            author:profiles!author_id(username, display_name),
            media:post_media!post_id(kind, thumb_path, storage_path)
          )
        ''')
        .or('sender.eq.$me,recipient.eq.$me')
        .order('created_at', ascending: true)
        .limit(1000);

    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final fromMe = '${r['sender']}' == me;
      final peerId = fromMe ? '${r['recipient']}' : '${r['sender']}';
      final peer = await _who(peerId);
      
      Map<String, dynamic>? postData;
      final p = r['post'];
      if (p != null && p is Map) {
        final author = _Who.fromRow(_embedded(p['author']));
        final mediaList = p['media'] as List?;
        String? thumb;
        bool isVideo = false;
        if (mediaList != null && mediaList.isNotEmpty) {
          final first = mediaList.first;
          if (first['kind'] == 'video') isVideo = true;
          final thumbPath = first['thumb_path'];
          if (thumbPath != null) {
            thumb = await _cachedFile('post-media', '$thumbPath');
          }
        }
        postData = {
          'post_id': '${p['id']}',
          'author_name': author.name,
          'author_handle': author.handle,
          'title': '${p['text'] ?? ''}',
          'thumb': thumb,
          'is_video': isVideo,
          'media_count': mediaList?.length ?? 0,
        };
      }

      out.add({
        'id': '${r['id']}',
        'peer_handle': peer.handle,
        'text': '${r['text']}',
        'from_me': fromMe,
        'created_at': '${r['created_at']}',
        'post_id': r['post_id'],
        'reply_to_id': r['reply_to_id'],
        'post_data': postData,
      });
    }
    return out;
  }

  Future<Map<String, dynamic>?> fetchPostById(String id) async {
    try {
      final rows = await _db
          .from('posts')
          .select('''
            id, text,
            author:profiles!author_id(username, display_name),
            media:post_media!post_id(kind, thumb_path, storage_path)
          ''')
          .eq('id', id)
          .maybeSingle();
      if (rows == null) return null;
      final author = _Who.fromRow(_embedded(rows['author']));
      final mediaList = rows['media'] as List?;
      String? thumb;
      bool isVideo = false;
      if (mediaList != null && mediaList.isNotEmpty) {
        final first = mediaList.first;
        if (first['kind'] == 'video') isVideo = true;
        final thumbPath = first['thumb_path'];
        if (thumbPath != null) {
          thumb = await _cachedFile('post-media', '$thumbPath');
        }
      }
      return {
        'id': '${rows['id']}',
        'author_name': author.name,
        'author_handle': author.handle,
        'text': '${rows['text'] ?? ''}',
        'thumb': thumb,
        'is_video': isVideo,
        'media_count': mediaList?.length ?? 0,
      };
    } catch (_) {
      return null;
    }
  }

  /// Rows: {handle, text, created_at} for notes from the last 24 hours.
  Future<List<Map<String, dynamic>>> fetchNotes() async {
    final since = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
    final rows = await _db
        .from('notes')
        .select('user_id,text,created_at')
        .gt('created_at', since);
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final who = await _who('${r['user_id']}');
      out.add({'handle': who.handle, 'text': '${r['text']}', 'created_at': '${r['created_at']}'});
    }
    return out;
  }

  /// Rows: {'key': 'work', 'value': 'Dev at Google', 'audience': 'everyone'}
  Future<List<Map<String, String>>> fetchProfileFields() async {
    final rows = await _db.from('profile_fields').select('key,value,audience').eq('user_id', _requireMe());
    return [
      for (final r in rows)
        {'key': '${r['key']}', 'value': '${r['value']}', 'audience': '${r['audience']}'},
    ];
  }

  // ---------------------------------------------------------------------------
  // STORIES
  // ---------------------------------------------------------------------------

  /// Saves a story: uploads its photo to the "stories" bucket, then stores the
  /// editor data. Returns the story id.
  Future<String> publishStory(StoryData data) async {
    final me = _requireMe();
    String? storagePath;
    final photo = data.photoPath;
    if (photo != null && File(photo).existsSync()) {
      final dot = photo.lastIndexOf('.');
      final ext = dot == -1 ? 'jpg' : photo.substring(dot + 1).toLowerCase();
      storagePath = '$me/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _db.storage.from('stories').upload(
            storagePath,
            File(photo),
            fileOptions: const FileOptions(upsert: true),
          );
    }
    final row = await _db.from('stories').insert({
      'author_id': me,
      'bg_color': data.bgColor,
      'photo_path': storagePath,
      'photo_scale': data.photoScale,
      'photo_dx': data.photoDx,
      'photo_dy': data.photoDy,
      'photo_rotation': data.photoRotation,
      'layers': [for (final l in data.layers) _layerToJson(l)],
      'place': data.place,
    }).select('id').single();
    return '${row['id']}';
  }

  static Map<String, dynamic> _layerToJson(StoryLayer l) => <String, dynamic>{
        'id': l.id,
        'kind': l.kind.name,
        'text': l.text,
        'color': l.color,
        'boxed': l.boxed,
        'dx': l.dx,
        'dy': l.dy,
        'scale': l.scale,
        'rotation': l.rotation,
      };

  /// Removes my story (its reactions and replies go with it).
  Future<void> deleteStory(String storyId) async {
    if (!isUuid(storyId)) return;
    await _db.from('stories').delete().eq('id', storyId).eq('author_id', _requireMe());
  }

  /// Active stories I can see (mine and people I follow), newest one per person.
  /// Each row has the story fields plus handle, name and photo_local (a file on this phone).
  Future<List<Map<String, dynamic>>> fetchStories() async {
    _requireMe();
    final rows = await _db
        .from('stories')
        .select('id,author_id,bg_color,photo_path,photo_scale,photo_dx,photo_dy,photo_rotation,layers,place,created_at,author:profiles!author_id(username,display_name)')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(300);
    final newest = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      newest.putIfAbsent('${r['author_id']}', () => Map<String, dynamic>.from(r));
    }
    final out = <Map<String, dynamic>>[];
    for (final r in newest.values) {
      final who = _Who.fromRow(_embedded(r['author']));
      final photoPath = r['photo_path'];
      out.add({
        ...r,
        'handle': who.handle,
        'name': who.name,
        'photo_local': photoPath == null ? null : await _cachedStoryPhoto('$photoPath'),
      });
    }
    return out;
  }

  Future<String?> _cachedStoryPhoto(String storagePath) => _cachedFile('stories', storagePath);

  /// Downloads a file from a bucket once and keeps it on the phone. Null if it fails.
  Future<String?> _cachedFile(String bucket, String storagePath) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/media_cache/$bucket/${storagePath.replaceAll('/', '_')}');
      if (await file.exists()) return file.path;
      await file.parent.create(recursive: true);
      final bytes = await _db.storage.from(bucket).download(storagePath);
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('[Swifly] file not downloaded ($bucket/$storagePath): $e');
      return null;
    }
  }

  /// Reactions and replies one story received, oldest first.
  /// Returns {'reactions': [{name, handle, emoji, created_at}], 'replies': [{name, handle, text, created_at}]}.
  Future<Map<String, List<Map<String, dynamic>>>> fetchStoryActivity(String storyId) async {
    if (!isUuid(storyId)) {
      return {'reactions': <Map<String, dynamic>>[], 'replies': <Map<String, dynamic>>[]};
    }
    final reactionRows = await _db
        .from('story_reactions')
        .select('emoji,created_at,who:profiles!user_id(username,display_name)')
        .eq('story_id', storyId)
        .order('created_at', ascending: true);
    final replyRows = await _db
        .from('story_replies')
        .select('text,created_at,who:profiles!user_id(username,display_name)')
        .eq('story_id', storyId)
        .order('created_at', ascending: true);
    return {
      'reactions': [
        for (final r in reactionRows)
          {
            'name': _Who.fromRow(_embedded(r['who'])).name,
            'handle': _Who.fromRow(_embedded(r['who'])).handle,
            'emoji': '${r['emoji']}',
            'created_at': '${r['created_at']}',
          },
      ],
      'replies': [
        for (final r in replyRows)
          {
            'name': _Who.fromRow(_embedded(r['who'])).name,
            'handle': _Who.fromRow(_embedded(r['who'])).handle,
            'text': '${r['text']}',
            'created_at': '${r['created_at']}',
          },
      ],
    };
  }

  /// Saves an emoji reaction to someone's story.
  Future<void> sendStoryReaction(String storyId, String emoji) async {
    if (!isUuid(storyId)) return;
    await _db.from('story_reactions').insert({
      'story_id': storyId,
      'user_id': _requireMe(),
      'emoji': emoji,
    });
  }

  /// Saves a text reply to someone's story.
  Future<void> sendStoryReply(String storyId, String text) async {
    if (!isUuid(storyId)) return;
    await _db.from('story_replies').insert({
      'story_id': storyId,
      'user_id': _requireMe(),
      'text': text,
    });
  }

    Future<void> clearLocalMediaCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final mediaDir = Directory('${dir.path}/media_cache');
      if (await mediaDir.exists()) await mediaDir.delete(recursive: true);
      final files = dir.listSync();
      for (final f in files) {
        if (f.path.contains('feed_cache_') && f.path.endsWith('.json')) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _embedded(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static String _handleOf(dynamic embeddedProfile) {
    final username = _embedded(embeddedProfile)['username'];
    return username == null ? '' : '@$username';
  }
}

/// A profile as the app needs it: id, username, shown name.
class _Who {
  final String id;
  final String username;
  final String name;

  final String? avatarUrl;
  const _Who({required this.id, required this.username, required this.name, this.avatarUrl});

  factory _Who.fromRow(Map<String, dynamic> r) {
    final username = '${r['username'] ?? ''}';
    final display = '${r['display_name'] ?? ''}'.trim();
    return _Who(
      id: '${r['id'] ?? ''}',
      username: username,
      name: display.isEmpty ? username : display,
      avatarUrl: r['avatar_url'] as String?,
    );
  }

  String get handle => '@$username';
}
