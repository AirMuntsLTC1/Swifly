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
String _nameOf(Map<String, dynamic> r) => _s(r['name'] ?? r['display_name'] ?? r['username']);
String _handleOf(Map<String, dynamic> r) =>
    r['handle'] != null ? _s(r['handle']) : (r['username'] != null ? '@${_s(r['username'])}' : '');

Person personFromRow(Map<String, dynamic> r) => Person(_nameOf(r), _handleOf(r));

CommentItem commentFromRow(Map<String, dynamic> r) => CommentItem(
      id: _s(r['id']).isEmpty ? null : _s(r['id']),
      name: _s(r['name']),
      text: _s(r['text']),
      created: _t(r['created_at']),
      replies: [
        if (r['replies'] is List)
          for (final x in r['replies'] as List) commentFromRow(Map<String, dynamic>.from(x as Map)),
      ],
    );

Post postFromRow(Map<String, dynamic> r) => Post(
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
    out.putIfAbsent(_s(r['peer_handle']), () => <ChatMessage>[]).add(ChatMessage(
          id: _s(r['id']).isEmpty ? null : _s(r['id']),
          text: _s(r['text']),
          fromMe: _b(r['from_me']),
          time: _t(r['created_at']),
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

Map<String, (int, int)> statsFromRows(List<Map<String, dynamic>> rows) => {
      for (final r in rows) _handleOf(r): (_i(r['followers_count']), _i(r['following_count'])),
    };

