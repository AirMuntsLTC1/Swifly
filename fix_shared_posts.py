import os
import shutil

def apply_fix(filepath, old_text, new_text, description):
    if not os.path.exists(filepath):
        print(f"❌ Could not find {filepath}")
        return
    shutil.copyfile(filepath, filepath + ".bak_fix_shared")
    with open(filepath, 'r') as f: content = f.read()
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f: f.write(content)
        print(f"✅ Fixed: {description}")
    else:
        print(f"⚠️ Skipped: {description} (pattern not found, might be already fixed)")

print("Applying Shared Post Thumbnail Fixes...\n")

# 1. Fix database_service.dart fetchMessages and add fetchPostById
db_service_path = "lib/database_service.dart"

old_db_snippet = """  Future<List<Map<String, dynamic>>> fetchMessages() async {
    final me = _requireMe();
    final rows = await _db
        .from('messages')
        .select('id,sender,recipient,text,reply_to_id,post_id,created_at')
        .or('sender.eq.$me,recipient.eq.$me')
        .order('created_at', ascending: true)
        .limit(1000);

    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final fromMe = '${r['sender']}' == me;
      final peerId = fromMe ? '${r['recipient']}' : '${r['sender']}';
      final peer = await _who(peerId);
      out.add({
        'id': '${r['id']}',
        'peer_handle': peer.handle,
        'text': '${r['text']}',
        'from_me': fromMe,
        'created_at': '${r['created_at']}',
        'post_id': r['post_id'],
        'reply_to_id': r['reply_to_id'],
      });
    }
    return out;
  }"""

new_db_snippet = """  Future<List<Map<String, dynamic>>> fetchMessages() async {
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
  }"""

apply_fix(db_service_path, old_db_snippet, new_db_snippet, "Fetch full post data for shared posts in messages")

# 2. Fix db_mappers.dart threadsFromRows
mapper_path = "lib/db_mappers.dart"

old_mapper_snippet = """/// Groups message rows into one thread per person, oldest message first.
Map<String, List<ChatMessage>> threadsFromRows(List<Map<String, dynamic>> rows) {
  final out = <String, List<ChatMessage>>{};
  for (final r in rows) {
    final text = _s(r['text']);
    final postId = r['post_id'];
    final replyToId = r['reply_to_id'];
    String displayText = text;
    
    if (displayText.isEmpty) {
      if (postId != null) displayText = "Shared a post";
      else if (replyToId != null) displayText = "Replied to a message";
      else displayText = "Story reply";
    }

    out.putIfAbsent(_s(r['peer_handle']), () => <ChatMessage>[]).add(ChatMessage(
          id: _s(r['id']).isEmpty ? null : _s(r['id']),
          text: displayText,
          fromMe: _b(r['from_me']),
          time: _t(r['created_at']),
        ));
  }
  for (final list in out.values) {
    list.sort((a, b) => a.time.compareTo(b.time));
  }
  return out;
}"""

new_mapper_snippet = """/// Groups message rows into one thread per person, oldest message first.
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
}"""

apply_fix(mapper_path, old_mapper_snippet, new_mapper_snippet, "Map shared post data back to PostRef in chat")

# 3. Fix realtime_router.dart to handle real-time shared posts
def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True) if os.path.dirname(path) else None
    with open(path, 'w') as f:
        f.write(content)
    print(f"✅ Updated: {path}")

write_file("lib/realtime_router.dart", """import 'dart:async';
import 'inbox_store.dart';
import 'post_model.dart';
import 'realtime.dart';
import 'database_service.dart';

class RealtimeRouter {
  static StreamSubscription<RealtimeEvent>? _sub;

  static void init() {
    _sub ??= Realtime.instance.stream.listen(_apply);
  }

  static void _apply(RealtimeEvent e) {
    if (e is PostChangedEvent) {
      final p = PostStore.instance.byId(e.postId);
      if (p != null) {
        p.likes = e.likes;
        p.saves = e.saves;
        p.shares = e.shares;
        PostStore.instance.notifyListeners();
      }
    } else if (e is NotificationAddedEvent) {
      NotificationStore.instance.insertFromRow(e.row);
    } else if (e is MessageReceivedEvent) {
      final senderId = e.row['sender'];
      final postId = e.row['post_id'];
      DatabaseService.instance.personById('\$senderId').then((who) async {
        PostRef? postRef;
        if (postId != null) {
          final p = await DatabaseService.instance.fetchPostById('\$postId');
          if (p != null) {
            postRef = PostRef(
              postId: p['id'],
              authorName: p['author_name'],
              authorHandle: p['author_handle'],
              title: p['text'],
              thumbPath: p['thumb'],
              isVideo: p['is_video'],
              mediaCount: p['media_count'],
            );
          }
        }
        ChatStore.instance.receive(who['handle']!, '\${e.row['text']}', post: postRef, story: null, replyTo: null);
      });
    } else if (e is ChatTypingEvent) {
      ChatTypingStore.instance.setTyping(e.handle, e.isTyping);
    }
  }
}
""")

print("\n🎉 All fixes applied successfully! You can now rebuild your app.")
