import os
import shutil

def apply_fix(filepath, old_text, new_text, description):
    if not os.path.exists(filepath):
        print(f"❌ Could not find {filepath}")
        return
    shutil.copyfile(filepath, filepath + ".bak")
    with open(filepath, 'r') as f: content = f.read()
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f: f.write(content)
        print(f"✅ Fixed: {description}")
    else:
        print(f"⚠️ Skipped: {description} (code already changed)")

print("Adding Offline-First Cache...\n")

# 1. Add toJson/fromJson to MediaItem
apply_fix(
    "lib/media/media_item.dart",
    """  String get durationLabel {
    final total = (durationMs / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}""",
    """  String get durationLabel {
    final total = (durationMs / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name, 'path': path, 'thumbPath': thumbPath,
    'width': width, 'height': height, 'durationMs': durationMs,
    'processing': processing, 'engine': engine,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    kind: json['kind'] == 'video' ? MediaKind.video : MediaKind.photo,
    path: json['path'],
    thumbPath: json['thumbPath'],
    width: json['width'] ?? 0,
    height: json['height'] ?? 0,
    durationMs: json['durationMs'] ?? 0,
    processing: json['processing'] ?? false,
    engine: json['engine'] ?? '',
  );
}""",
    "Added JSON serialization to MediaItem"
)

# 2. Add toJson/fromJson to Post and CommentItem, plus Cache logic to PostStore
apply_fix(
    "lib/post_model.dart",
    "import 'app_feedback.dart';\nimport 'package:flutter/foundation.dart';\n\nimport 'media/media_item.dart';",
    "import 'app_feedback.dart';\nimport 'dart:convert';\nimport 'dart:io';\nimport 'package:flutter/foundation.dart';\nimport 'package:path_provider/path_provider.dart';\n\nimport 'media/media_item.dart';",
    "Added imports for JSON and File to post_model.dart"
)

apply_fix(
    "lib/post_model.dart",
    """    String? id,
    List<CommentItem>? replies,
  })  : id = id ?? 'c${++_commentSeq}',
        replies = replies ?? <CommentItem>[];
}""",
    """    String? id,
    List<CommentItem>? replies,
  })  : id = id ?? 'c${++_commentSeq}',
        replies = replies ?? <CommentItem>[];

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'text': text,
    'created': created.toIso8601String(),
    'replies': replies.map((r) => r.toJson()).toList(),
  };

  factory CommentItem.fromJson(Map<String, dynamic> json) => CommentItem(
    id: json['id'], name: json['name'], text: json['text'],
    created: DateTime.parse(json['created']),
    replies: (json['replies'] as List? ?? []).map((r) => CommentItem.fromJson(r)).toList(),
  );
}""",
    "Added JSON serialization to CommentItem"
)

apply_fix(
    "lib/post_model.dart",
    """  String get timeLabel {
    final d = DateTime.now().difference(created);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}""",
    """  String get timeLabel {
    final d = DateTime.now().difference(created);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'authorName': authorName, 'authorHandle': authorHandle,
    'text': text, 'audience': audience, 'taggedHandles': taggedHandles,
    'created': created.toIso8601String(), 'likes': likes, 'liked': liked,
    'saves': saves, 'saved': saved, 'shares': shares,
    'media': media.map((m) => m.toJson()).toList(),
    'comments': comments.map((c) => c.toJson()).toList(),
  };

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'], authorName: json['authorName'], authorHandle: json['authorHandle'],
    text: json['text'], audience: json['audience'],
    taggedHandles: List<String>.from(json['taggedHandles'] ?? []),
    created: DateTime.parse(json['created']),
    likes: json['likes'] ?? 0, liked: json['liked'] ?? false,
    saves: json['saves'] ?? 0, saved: json['saved'] ?? false, shares: json['shares'] ?? 0,
    media: (json['media'] as List? ?? []).map((m) => MediaItem.fromJson(m)).toList(),
    comments: (json['comments'] as List? ?? []).map((c) => CommentItem.fromJson(c)).toList(),
  );
}""",
    "Added JSON serialization to Post"
)

# 3. Add saveCache and loadCache to PostStore
apply_fix(
    "lib/post_model.dart",
    """  /// Call when the PHP pipeline finishes a photo or video that a post already shows.
  void mediaUpdated() => notifyListeners();
""",
    """  /// Call when the PHP pipeline finishes a photo or video that a post already shows.
  void mediaUpdated() => notifyListeners();

  Future<void> saveCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/feed_cache.json');
      final data = _posts.take(20).map((p) => p.toJson()).toList(); // Cache top 20 posts
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> loadCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/feed_cache.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as List;
        final cachedPosts = data.map((item) => Post.fromJson(item)).toList();
        // Only load cache if memory is empty (don't overwrite fresh data)
        if (_posts.isEmpty) {
          _posts.addAll(cachedPosts);
          notifyListeners();
        }
      }
    } catch (_) {}
  }
""",
    "Added saveCache and loadCache to PostStore"
)

# 4. Save cache after fetching
apply_fix(
    "lib/app_bootstrap.dart",
    """  PostStore.instance.load(posts: [
    ...pending,
    for (final r in filteredSaved) postFromRow(r),
  ]);
}""",
    """  PostStore.instance.load(posts: [
    ...pending,
    for (final r in filteredSaved) postFromRow(r),
  ]);
  PostStore.instance.saveCache();
}""",
    "Save cache after fetching posts from Supabase"
)

# 5. Load cache during splash screen startup
apply_fix(
    "lib/splash_screen.dart",
    """        AuthService.instance.applyUser();
        setState(() => _status = 'Loading your feed...');
        await loadAppData();""",
    """        AuthService.instance.applyUser();
        setState(() => _status = 'Loading your feed...');
        await PostStore.instance.loadCache(); // Load offline cache instantly
        await loadAppData();""",
    "Load offline cache instantly on startup"
)
apply_fix(
    "lib/splash_screen.dart",
    "import 'auth_service.dart';",
    "import 'auth_service.dart';\nimport 'post_model.dart';",
    "Added post_model import to splash_screen"
)

print("\n✅ Offline First Cache implemented successfully!")
