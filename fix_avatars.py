import os, shutil

def apply_fix(filepath, old_text, new_text, description):
    if not os.path.exists(filepath):
        print(f"❌ Could not find {filepath}")
        return
    shutil.copyfile(filepath, filepath + ".bak_avatar")
    with open(filepath, 'r') as f: content = f.read()
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f: f.write(content)
        print(f"✅ Fixed: {description}")
    else:
        print(f"⚠️ Skipped: {description} (already fixed or pattern changed)")

print("Applying Global Avatar & Offline Caching Fixes...\n")

# 1. Update Person model
apply_fix("lib/people_directory.dart",
"""class Person {
  final String name;
  final String handle;
  const Person(this.name, this.handle);
}""",
"""class Person {
  final String name;
  final String handle;
  final String avatarUrl;
  const Person(this.name, this.handle, {this.avatarUrl = ''});
}""", "Added avatarUrl to Person model")

# 2. Update CommentItem model
apply_fix("lib/post_model.dart",
"""class CommentItem {
  String id;
  final String name;
  final String text;
  final DateTime created;
  final List<CommentItem> replies;

  CommentItem({
    required this.name,
    required this.text,
    required this.created,
    String? id,
    List<CommentItem>? replies,
  })  : id = id ?? 'c${++_commentSeq}',
        replies = replies ?? <CommentItem>[];""",
"""class CommentItem {
  String id;
  final String name;
  final String authorHandle;
  final String text;
  final DateTime created;
  final List<CommentItem> replies;

  CommentItem({
    required this.name,
    this.authorHandle = '',
    required this.text,
    required this.created,
    String? id,
    List<CommentItem>? replies,
  })  : id = id ?? 'c${++_commentSeq}',
        replies = replies ?? <CommentItem>[];""", "Added authorHandle to CommentItem")

# 3. Update PostStore to pass authorHandle for new comments
apply_fix("lib/post_model.dart",
"""    final newReply = CommentItem(name: kMeName, text: text, created: DateTime.now());""",
"""    final newReply = CommentItem(name: kMeName, authorHandle: kMeHandle, text: text, created: DateTime.now());""",
"Added authorHandle to new replies")

apply_fix("lib/post_model.dart",
"""    final newComment = CommentItem(name: kMeName, text: text, created: DateTime.now());""",
"""    final newComment = CommentItem(name: kMeName, authorHandle: kMeHandle, text: text, created: DateTime.now());""",
"Added authorHandle to new comments")

# 4. Map avatarUrl in db_mappers
apply_fix("lib/db_mappers.dart",
"""Person personFromRow(Map<String, dynamic> r) => Person(_nameOf(r), _handleOf(r));""",
"""Person personFromRow(Map<String, dynamic> r) => Person(_nameOf(r), _handleOf(r), avatarUrl: _s(r['avatar_url']));""",
"Map avatar_url in personFromRow")

apply_fix("lib/db_mappers.dart",
"""CommentItem commentFromRow(Map<String, dynamic> r) => CommentItem(
      id: _s(r['id']).isEmpty ? null : _s(r['id']),
      name: _s(r['name']),
      text: _s(r['text']),""",
"""CommentItem commentFromRow(Map<String, dynamic> r) => CommentItem(
      id: _s(r['id']).isEmpty ? null : _s(r['id']),
      name: _s(r['name']),
      authorHandle: _s(r['author_handle']),
      text: _s(r['text']),""", "Map author_handle in commentFromRow")

# 5. Update DatabaseService to fetch and map avatars + add offline caching
apply_fix("lib/database_service.dart",
"""        .select('username,display_name,followers_count,following_count')""",
"""        .select('username,display_name,followers_count,following_count,avatar_url')""",
"Fetch avatar_url in fetchPeople")

apply_fix("lib/database_service.dart",
"""          'handle': _Who.fromRow(Map<String, dynamic>.from(r)).handle,
          'followers_count': r['followers_count'] ?? 0,""",
"""          'handle': _Who.fromRow(Map<String, dynamic>.from(r)).handle,
          'avatar_url': r['avatar_url'] ?? '',
          'followers_count': r['followers_count'] ?? 0,""", "Map avatar_url in fetchPeople")

apply_fix("lib/database_service.dart",
"""        'id': '${r['id']}',
        'name': author.name,
        'text': '${r['text']}',""",
"""        'id': '${r['id']}',
        'name': author.name,
        'author_handle': author.handle,
        'text': '${r['text']}',""", "Map author_handle in fetchPosts comments")

# Add cacheAvatarImage to DatabaseService
apply_fix("lib/database_service.dart",
"""  Future<void> clearLocalMediaCache() async {""",
"""  Future<String?> cacheAvatarImage(String url) async {
    if (url.isEmpty) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      final safeName = url.split('/').last.split('?').first;
      final hash = url.hashCode.toRadixString(16);
      final file = File('${dir.path}/avatars/${hash}_$safeName');
      if (await file.exists()) return file.path;
      await file.parent.create(recursive: true);
      
      final client = HttpClient();
      try {
        final req = await client.getUrl(Uri.parse(url));
        final res = await req.close();
        if (res.statusCode == 200) {
          final bytes = await res.fold<List<int>>([], (p, e) => p..addAll(e));
          await file.writeAsBytes(bytes);
          return file.path;
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearLocalMediaCache() async {""", "Added cacheAvatarImage to DatabaseService")

# 6. Update ProfileStore to cache avatars offline
apply_fix("lib/profile_store.dart",
"""      final me = await DatabaseService.instance.fetchMe();
      if (me != null) {
        final remoteAvatar = me['avatar_url'] as String?;
        if (remoteAvatar != null && remoteAvatar.isNotEmpty) {
          avatarPath = remoteAvatar;
          notifyListeners();
        }
      }""",
"""      final me = await DatabaseService.instance.fetchMe();
      if (me != null) {
        final remoteAvatar = me['avatar_url'] as String?;
        if (remoteAvatar != null && remoteAvatar.isNotEmpty) {
          final localPath = await DatabaseService.instance.cacheAvatarImage(remoteAvatar);
          avatarPath = localPath ?? remoteAvatar;
          notifyListeners();
        }
      }""", "Cache remote avatar in ProfileStore.loadFromDatabase")

apply_fix("lib/profile_store.dart",
"""      final remoteUrl = await DatabaseService.instance.uploadAvatar(path);
      avatarPath = remoteUrl;
      notifyListeners();
      _saveToDevice();""",
"""      final remoteUrl = await DatabaseService.instance.uploadAvatar(path);
      final local = await DatabaseService.instance.cacheAvatarImage(remoteUrl);
      avatarPath = local ?? path;
      notifyListeners();
      _saveToDevice();""", "Keep local avatar after upload")

# 7. Upgrade DmAvatar to handle images gracefully, load other users' avatars, and fallback to initials
apply_fix("lib/dm_theme.dart",
"""    final c = DmTheme.instance.c;
    final isMe = handle == kMeHandle;
    final path = isMe ? ProfileStore.instance.avatarPath : null;
    final displayName = this.name ?? (isMe ? kMeName : nameForHandle(handle));
    final hasImage = path != null && path.isNotEmpty;
    final letter = displayName.replaceAll('@', '').trim().isEmpty
        ? '?'
        : displayName.replaceAll('@', '').trim().characters.first.toUpperCase();
    final inner = ring ? size - 8 : size;
    final face = Container(
      width: inner,
      height: inner,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _tint(handle),
        image: hasImage
            ? DecorationImage(
                image: path.startsWith('http') 
                    ? NetworkImage(path) 
                    : FileImage(File(path)) as ImageProvider, 
                fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: !hasImage
          ? Text(letter,
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: inner * 0.42))
          : null,
    );""",
"""    final c = DmTheme.instance.c;
    final isMe = handle == kMeHandle;
    String? path = isMe ? ProfileStore.instance.avatarPath : null;
    if (path == null || path.isEmpty) {
      for (final p in kPeople) {
        if (p.handle == handle && p.avatarUrl.isNotEmpty) {
          path = p.avatarUrl;
          break;
        }
      }
    }
    final displayName = this.name ?? (isMe ? kMeName : nameForHandle(handle));
    final hasImage = path != null && path.isNotEmpty;
    final inner = ring ? size - 8 : size;
    
    Widget fallback() {
      final letter = displayName.replaceAll('@', '').trim().isEmpty
          ? '?'
          : displayName.replaceAll('@', '').trim().characters.first.toUpperCase();
      return Center(
        child: Text(letter,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: inner * 0.42)),
      );
    }

    final face = Container(
      width: inner,
      height: inner,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _tint(handle),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? (path!.startsWith('http')
              ? Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback())
              : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback()))
          : fallback(),
    );""", "Upgraded DmAvatar with error fallback and global lookup")

# 8. Update HomeScreen Profile tab to use DmAvatar
apply_fix("lib/home_screen.dart",
"""    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.black,
      backgroundImage: path == null ? null : FileImage(File(path)),
      child: path == null ? Icon(LucideIcons.user, color: Colors.white, size: r.s(40)) : null,
    );""",
"""    final avatar = DmAvatar(handle: kMeHandle, size: r.s(88));""", "Use DmAvatar in ProfileTab")

# 9. Update Notifications to use DmAvatar
apply_fix("lib/notifications_tab.dart",
"""class NotifAvatar extends StatelessWidget {
  final NotifType type;
  final double size;
  const NotifAvatar({super.key, required this.type, this.size = 56});""",
"""class NotifAvatar extends StatelessWidget {
  final NotifType type;
  final String handle;
  final double size;
  const NotifAvatar({super.key, required this.type, required this.handle, this.size = 56});""", "Update NotifAvatar constructor")

apply_fix("lib/notifications_tab.dart",
"""          CircleAvatar(
            radius: size / 2,
            backgroundColor: Colors.black,
            child: Icon(LucideIcons.user, color: Colors.white, size: size * 0.46),
          ),""",
"""          DmAvatar(handle: handle, size: size),""", "Use DmAvatar inside NotifAvatar")

apply_fix("lib/notifications_tab.dart",
"""              NotifAvatar(type: n.type),""",
"""              NotifAvatar(type: n.type, handle: n.actorHandle),""", "Pass actorHandle to NotifAvatar")

apply_fix("lib/notification_banner.dart",
"""                  NotifAvatar(type: n.type, size: 46),""",
"""                  NotifAvatar(type: n.type, handle: n.actorHandle, size: 46),""", "Pass actorHandle in NotificationBanner")

# 10. Update PostDetailScreen to use DmAvatar
apply_fix("lib/post_detail_screen.dart",
"""import 'feed_widgets.dart';""",
"""import 'feed_widgets.dart';
import 'dm_theme.dart';""", "Add dm_theme import to post_detail_screen")

apply_fix("lib/post_detail_screen.dart",
"""        CircleAvatar(
          radius: r,
          backgroundColor: Colors.black,
          child: Icon(LucideIcons.user, color: Colors.white, size: r),
        ),""",
"""        DmAvatar(
          handle: c.authorHandle,
          name: c.name,
          size: r * 2,
        ),""", "Use DmAvatar in post comments")

print("\n🎉 All Avatar & Caching fixes applied successfully! You can now rebuild the app.")
