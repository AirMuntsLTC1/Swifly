/// One photo or video attached to a post. Plain data, no processing here.
/// The processing is done by the PHP pipeline (cpp/php/*.php) through C++.
enum MediaKind { photo, video }

class MediaItem {
  MediaKind kind;

  /// File to display or play. Before processing finishes this is the gallery file;
  /// afterwards it is the cached copy.
  String path;

  /// Small preview image (cached thumbnail). Null or empty if none exists yet.
  String? thumbPath;

  int width;
  int height;
  int durationMs;

  /// True while the PHP pipeline is still working on this item.
  bool processing;

  /// php-gd, php, cpp-fallback or empty (not processed).
  String engine;

  MediaItem({
    required this.kind,
    required this.path,
    this.thumbPath,
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
    this.processing = false,
    this.engine = '',
  });

  bool get isVideo => kind == MediaKind.video;

  /// The image to show right away: the thumbnail, or the photo itself.
  /// Videos without a thumbnail return null (the tile shows a placeholder).
  String? get previewPath {
    final t = thumbPath;
    if (t != null && t.isNotEmpty) return t;
    return isVideo ? null : path;
  }

  /// Builds an item from the JSON line printed by the PHP pipeline.
  factory MediaItem.fromResult(Map<String, dynamic> json, {required MediaItem fallback}) {
    final thumb = (json['thumb'] as String?) ?? '';
    return MediaItem(
      kind: json['kind'] == 'video' ? MediaKind.video : MediaKind.photo,
      path: (json['path'] as String?) ?? fallback.path,
      thumbPath: thumb.isNotEmpty ? thumb : fallback.thumbPath,
      width: (json['w'] as num?)?.toInt() ?? 0,
      height: (json['h'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      processing: false,
      engine: (json['engine'] as String?) ?? '',
    );
  }

  /// Updates this item in place, so a post that already holds it shows the result.
  void copyFrom(MediaItem other) {
    kind = other.kind;
    path = other.path;
    thumbPath = other.thumbPath;
    width = other.width;
    height = other.height;
    durationMs = other.durationMs;
    processing = other.processing;
    engine = other.engine;
  }

  String get durationLabel {
    final total = (durationMs / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}



