import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'media_item.dart';
import 'preview_image.dart';
import 'video_autoplay.dart';

/// Last known playback position of every video file. The feed and the post
/// (Comment) page each have their own player for the same file; this is how
/// the second one carries on from where the first one stopped.
final Map<String, Duration> _kResume = <String, Duration>{};

/// A video in a post.
///  - The cached thumbnail shows instantly; no player exists yet.
///  - When the video is mostly on screen, the player starts (muted, looping).
///  - When another page opens on top (Comment button), this video pauses, remembers
///    its position, and the video on the new page continues from that position.
///    Going back does the same in reverse.
///  - When it leaves the screen it pauses; 2 seconds later the player is released.
class VideoTile extends StatefulWidget {
  final MediaItem item;

  /// Unique per video in the feed (post id + position).
  final String tileId;

  /// False when this video is on another page of the post's swipe gallery.
  final bool pageActive;

  const VideoTile({
    super.key,
    required this.item,
    required this.tileId,
    this.pageActive = true,
  });

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _starting = false;
  double _fraction = 0;
  Timer? _releaseTimer;

  /// False while another page is open on top of this one.
  bool _routeActive = true;

  /// False while the whole app is in the background.
  bool _appActive = true;

  bool _lastPlaying = false;
  bool _lastShown = false;

  /// The same post can be on screen twice (feed + post page). Each tile gets its
  /// own id, so one can never switch the other one off.
  late final String _uid = '${widget.tileId}@${identityHashCode(this)}';

  VideoAutoplay get _auto => VideoAutoplay.instance;
  bool get _shouldPlay =>
      widget.pageActive && _routeActive && _appActive && _auto.isActive(_uid);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auto.addListener(_sync);
    _auto.muted.addListener(_applyMute);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.of makes this run again when a page is pushed on top or removed.
    final active = ModalRoute.of(context)?.isCurrent ?? true;
    if (active != _routeActive) {
      _routeActive = active;
      if (!active) _savePosition();
      _report();
      _sync();
    }
  }

  @override
  void didUpdateWidget(covariant VideoTile old) {
    super.didUpdateWidget(old);
    if (old.pageActive != widget.pageActive) {
      _report();
      _sync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    if (!active) _savePosition();
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _savePosition();
    _auto.removeListener(_sync);
    _auto.muted.removeListener(_applyMute);
    _auto.remove(_uid);
    _releaseTimer?.cancel();
    _controller?.removeListener(_onPlayerChanged);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _savePosition() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    _kResume[widget.item.path] = c.value.position;
  }

  void _report() {
    final visible = widget.pageActive && _routeActive;
    _auto.report(_uid, visible ? _fraction : 0);
  }

  void _applyMute() {
    _controller?.setVolume(_auto.muted.value ? 0 : 1);
    if (mounted) setState(() {});
  }

  /// Redraws when the player really starts or stops, so the picture can never stay
  /// frozen on the thumbnail while the sound keeps going.
  void _onPlayerChanged() {
    final c = _controller;
    if (c == null || !mounted) return;
    if (c.value.hasError) {
      c.removeListener(_onPlayerChanged);
      c.dispose();
      _controller = null;
      _lastPlaying = false;
      _lastShown = false;
      setState(() {});
      return;
    }
    final playing = c.value.isInitialized && c.value.isPlaying;
    // Keep the shared position fresh while playing, so the other page always
    // continues from the right spot.
    if (playing) _kResume[widget.item.path] = c.value.position;
    final shown = c.value.isInitialized && (playing || c.value.position > Duration.zero);
    if (playing != _lastPlaying || shown != _lastShown) {
      _lastPlaying = playing;
      _lastShown = shown;
      setState(() {});
    }
  }

  void _sync() {
    if (!mounted) return;
    if (_shouldPlay) {
      _releaseTimer?.cancel();
      _play();
    } else {
      _savePosition();
      _controller?.pause();
      _scheduleRelease();
    }
  }

  Future<void> _play() async {
    if (_starting) return;
    var c = _controller;
    final path = widget.item.path;

    if (c == null) {
      _starting = true;
      c = VideoPlayerController.file(
        File(path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = c;
      try {
        await c.initialize();
        await c.setLooping(true);
        await c.setVolume(_auto.muted.value ? 0 : 1);
        final saved = _kResume[path];
        if (saved != null && saved > Duration.zero && saved < c.value.duration) {
          await c.seekTo(saved);
        }
      } catch (_) {
        c.dispose();
        if (_controller == c) _controller = null;
        _starting = false;
        return; // the thumbnail stays; nothing else to do
      }
      _starting = false;
      if (!mounted) {
        c.dispose();
        return;
      }
      c.addListener(_onPlayerChanged);
      setState(() {});
    } else {
      // This player may be behind the other one (feed vs post page). Catch up.
      final saved = _kResume[path];
      if (saved != null &&
          c.value.isInitialized &&
          saved < c.value.duration &&
          (c.value.position - saved).abs() > const Duration(milliseconds: 400)) {
        await c.seekTo(saved);
      }
    }

    if (!mounted || _controller != c) return;
    // The video may have scrolled away (or a page opened on top) while it was starting.
    if (_shouldPlay) {
      await c.play();
    } else {
      await c.pause();
    }
    if (mounted) setState(() {});
  }

  void _scheduleRelease() {
    _releaseTimer?.cancel();
    if (_controller == null) return;
    _releaseTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _shouldPlay || _starting) return;
      _savePosition();
      _controller?.removeListener(_onPlayerChanged);
      _controller?.dispose();
      _controller = null;
      _lastPlaying = false;
      _lastShown = false;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final playing = ready && c.value.isPlaying;
    // Keep the live picture once it has started (even when paused) so it never
    // jumps back to the old thumbnail.
    final shown = ready && (playing || c.value.position > Duration.zero);

    return VisibilityDetector(
      key: ValueKey('vis_$_uid'),
      onVisibilityChanged: (info) {
        _fraction = info.visibleFraction;
        _report();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _auto.muted.value = !_auto.muted.value,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Thumbnail: always there, so there is never an empty box.
            PreviewImage(
              path: item.thumbPath,
              cacheWidth: 800,
              placeholderIcon: LucideIcons.video,
            ),
            // 2. The player fades in once it has a picture.
            if (ready)
              AnimatedOpacity(
                opacity: shown ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: c.value.size.width,
                      height: c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
              ),
            // 3. Small labels.
            if (item.durationMs > 0)
              Positioned(
                left: 10,
                bottom: 10,
                child: _Chip(text: item.durationLabel),
              ),
            if (playing)
              Positioned(
                right: 10,
                bottom: 10,
                child: _Chip(
                  icon: _auto.muted.value ? LucideIcons.volumeX : LucideIcons.volume2,
                ),
              )
            else if (item.processing)
              const Positioned(
                right: 10,
                bottom: 10,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String? text;
  final IconData? icon;
  const _Chip({this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: icon != null
          ? Icon(icon, size: 14, color: Colors.white)
          : Text(text ?? '',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}


