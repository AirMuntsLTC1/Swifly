import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps every profile picture on the phone after the first download.
///
/// The file name comes from a stable hash of the URL (Dart's own String.hashCode
/// is not stable between app launches, so it cannot be used for file names).
/// Pictures that are already on disk show without any network request.
class AvatarCache {
  AvatarCache._();
  static final AvatarCache instance = AvatarCache._();

  /// URL -> local file path, for pictures already on the phone.
  final Map<String, String> _ready = {};

  /// URL -> download still in progress (so one picture is never fetched twice at once).
  final Map<String, Future<String?>> _pending = {};

  Directory? _dir;

  /// The local file for [url] if it is already here. Synchronous, so it can be
  /// used in build() without flicker.
  String? cachedPath(String url) => _ready[url];

  /// Local file for [url]. Downloads it once if needed. Null if it cannot be loaded.
  Future<String?> pathFor(String url) {
    if (url.isEmpty || !url.startsWith('http')) return Future.value(null);
    final ready = _ready[url];
    if (ready != null) return Future.value(ready);
    return _pending.putIfAbsent(url, () => _download(url));
  }

  Future<String?> _download(String url) async {
    try {
      _dir ??= Directory('${(await getApplicationSupportDirectory()).path}/avatars');
      final dir = _dir!;
      if (!await dir.exists()) await dir.create(recursive: true);

      final file = File('${dir.path}/${_fileKey(url)}.img');
      if (await file.exists() && await file.length() > 0) {
        _ready[url] = file.path;
        return file.path;
      }

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final req = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 10));
        final res = await req.close().timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) return null;
        final bytes = await res.fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
        if (bytes.isEmpty) return null;

        // Write to a temp file first, so a half-written picture is never used.
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename(file.path);
        _ready[url] = file.path;
        return file.path;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    } finally {
      _pending.remove(url);
    }
  }

  /// Forget everything on the phone (used on sign out).
  Future<void> clear() async {
    _ready.clear();
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/avatars');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Two 32-bit hashes of the URL, written as hex. Stable across launches.
  static String _fileKey(String url) {
    var fnv = 0x811c9dc5;
    var djb = 5381;
    for (final c in url.codeUnits) {
      fnv = ((fnv ^ c) * 0x01000193) & 0xffffffff;
      djb = ((djb * 33) ^ c) & 0xffffffff;
    }
    return '${fnv.toRadixString(16)}_${djb.toRadixString(16)}_${url.length}';
  }
}

/// Image provider for an avatar path: a saved file if there is one (no download),
/// otherwise the network picture, which is also saved for next time.
ImageProvider avatarImageProvider(String path) {
  if (!path.startsWith('http')) return FileImage(File(path));
  final local = AvatarCache.instance.cachedPath(path);
  if (local != null) return FileImage(File(local));
  AvatarCache.instance.pathFor(path);
  return NetworkImage(path);
}

/// A round-ready picture from the URL. It shows the saved file at once, and
/// downloads only the first time the picture is needed. [fallback] shows while
/// there is no picture yet, or if the download fails.
class CachedAvatarImage extends StatefulWidget {
  final String url;
  final double size;
  final Widget fallback;

  const CachedAvatarImage({
    super.key,
    required this.url,
    required this.size,
    required this.fallback,
  });

  @override
  State<CachedAvatarImage> createState() => _CachedAvatarImageState();
}

class _CachedAvatarImageState extends State<CachedAvatarImage> {
  String? _path;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CachedAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  void _resolve() {
    final url = widget.url;
    final ready = AvatarCache.instance.cachedPath(url);
    _path = ready;
    if (ready != null) return;
    AvatarCache.instance.pathFor(url).then((p) {
      if (!mounted || url != widget.url || p == null) return;
      setState(() => _path = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _path;
    if (p == null) return widget.fallback;
    return Image.file(
      File(p),
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
}
