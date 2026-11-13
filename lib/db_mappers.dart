import 'media/media_item.dart';
import 'story_models.dart';
import 'inbox_store.dart';
import 'people_directory.dart';
import 'post_model.dart';

/// Turns database rows into the objects the screens use.
/// Missing or null columns never crash the app.

String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;
bool _b(dynamic v) => v == true || v == 1 || v == 'true';
DateTime _t(dynamic v) => DateTime.tryParse(_s(v))?.toLocal() ?? DateTime.now();
List<String> _list(dynamic v) => v is List ? [for (final e in v) e.toString()] : <String>[];

/// Accepts name/handle or display_name/username columns.
double _d(dynamic v, double d) => v is num ? v.toDouble() : d;

String _nameOf(Map<String, dynamic> r) => _s(r['name'] ?? r['display_name'] ?? r['username']);
String _handleOf(Map<String, dynamic> r) =>
    r['handle'] != null ? _s(r['handle']) : (r['username'] != null ? '@${_s(r['username'])}' : '');

Person personFromRow(Map<String, dynamic> r) => Person(_nameOf(r), _handleOf(r), avatarUrl: _s(r['avatar_url']));

CommentItem commentFromRow(Map<String, dynamic> r) => CommentItem(
      id: _s(r['id']).isEmpty ? null : _s(r['id']),
      name: _s(r['name']),
      authorHandle: _s(r['author_handle']),
      text: _s(r['text']),
      created: _t(r['created_at']),
      replies: [
        if (r['replies'] is List)
          for (final x in r['replies'] as List) commentFromRow(Map<String, dynamic>.from(x as Map)),
      ],
    );

/// One saved photo or video, already downloaded to this phone.
MediaItem mediaFromRow(Map<String, dynamic> r) => MediaItem(
      kind: _s(r['kind']) == 'video' ? MediaKind.video : MediaKind.photo,
      path: _s(r['path']),
      thumbPath: r['thumb'] == null ? null : _s(r['thumb']),
      width: _i(r['width']),
      height: _i(r['height']),
      durationMs: _i(r['duration_ms']),
      processing: false,
      engine: _s(r['engine']),
    );

Post postFromRow(Map<String, dynamic> r) => Post(
      media: [
        if (r['media'] is List)
          for (final m in r['media'] as List) mediaFromRow(Map<String, dynamic>.from(m as Map)),
      ],
      id: _s(r['id']),
      authorName: _s(r['author_name']),
      authorHandle: _s(r['author_handle']),
      text: _s(r['text']),
      audience: _s(r['audience'], 'Everyone'),
      created: _t(r['created_at']),
      taggedHandles: _list(r['tagged_handles']),
      likes: _i(r['likes']),
      liked: _b(r['liked']),
      saves: _i(r['saves']),
      saved: _b(r['saved']),
      shares: _i(r['shares']),
      comments: [
        if (r['comments'] is List)
          for (final x in r['comments'] as List) commentFromRow(Map<String, dynamic>.from(x as Map)),
      ],
    );

AppNotification notificationFromRow(Map<String, dynamic> r) => AppNotification(
      id: _s(r['id']),
      type: NotifType.values.firstWhere(
        (t) => t.name == _s(r['type']),
        orElse: () => NotifType.like,
      ),
      actorName: _s(r['actor_name']),
      actorHandle: _s(r['actor_handle']),
      created: _t(r['created_at']),
      postId: r['post_id'] == null ? null : _s(r['post_id']),
      commentId: r['comment_id'] == null ? null : _s(r['comment_id']),
      emoji: r['emoji'] == null ? null : _s(r['emoji']),
      preview: r['preview'] == null ? null : _s(r['preview']),
      read: _b(r['read']),
    );

/// Groups message rows into one thread per person, oldest message first.
Map<String, List<ChatMessage>> threadsFromRows(List<Map<String, dynamic>> rows) {
  final out = <String, List<ChatMessage>>{};
  for (final r in rows) {
    final text = _s(r['text']);
    final postId = r['post_id'];
    final replyToId = r['reply_to_id'];
    final postData = r['post_data'];
    
    String displayText = text;
    PostRef? postRef;
    
    if (postData != null && postData is Map) {
      postRef = PostRef(
        postId: _s(postData['post_id']),
        authorName: _s(postData['author_name']),
        authorHandle: _s(postData['author_handle']),
        title: _s(postData['title']),
        thumbPath: postData['thumb'] == null ? null : _s(postData['thumb']),
        isVideo: _b(postData['is_video']),
        mediaCount: _i(postData['media_count']),
      );
    } else if (displayText.isEmpty) {
      if (postId != null) displayText = "Shared a post";
      else if (replyToId != null) displayText = "Replied to a message";
      else displayText = "Story reply";
    }

    out.putIfAbsent(_s(r['peer_handle']), () => <ChatMessage>[]).add(ChatMessage(
          id: _s(r['id']).isEmpty ? null : _s(r['id']),
          text: displayText,
          fromMe: _b(r['from_me']),
          time: _t(r['created_at']),
          post: postRef,
        ));
  }
  for (final list in out.values) {
    list.sort((a, b) => a.time.compareTo(b.time));
  }
  return out;
}

Map<String, DmNote> notesFromRows(List<Map<String, dynamic>> rows) => {
      for (final r in rows)
        _s(r['handle']): DmNote(handle: _s(r['handle']), text: _s(r['text']), time: _t(r['created_at'])),
    };

StoryLayer _layerFromJson(Map<String, dynamic> j) => StoryLayer(
      id: _s(j['id'], 'layer'),
      kind: StoryLayerKind.values.firstWhere(
        (k) => k.name == _s(j['kind']),
        orElse: () => StoryLayerKind.text,
      ),
      text: _s(j['text']),
      color: j['color'] is num ? (j['color'] as num).toInt() : 0xFFFFFFFF,
      boxed: _b(j['boxed']),
      dx: _d(j['dx'], 0.5),
      dy: _d(j['dy'], 0.5),
      scale: _d(j['scale'], 1),
      rotation: _d(j['rotation'], 0),
    );

/// One active story row (from DatabaseService.fetchStories) as the app's OtherStory.
OtherStory storyFromRow(Map<String, dynamic> r) {
  final layers = r['layers'] is List ? r['layers'] as List : const [];
  final bg = r['bg_color'];
  return OtherStory(
    id: _s(r['id']),
    time: _t(r['created_at']),
    data: StoryData(
      bgColor: bg is num ? bg.toInt() : 0xFF1D6FDC,
      photoPath: r['photo_local'] == null ? null : _s(r['photo_local']),
      photoScale: _d(r['photo_scale'], 1),
      photoDx: _d(r['photo_dx'], 0),
      photoDy: _d(r['photo_dy'], 0),
      photoRotation: _d(r['photo_rotation'], 0),
      layers: [for (final l in layers) _layerFromJson(Map<String, dynamic>.from(l as Map))],
    ),
  );
}

Map<String, (int, int)> statsFromRows(List<Map<String, dynamic>> rows) => {
      for (final r in rows) _handleOf(r): (_i(r['followers_count']), _i(r['following_count'])),
    };

