import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'media_item.dart';
import 'preview_image.dart';
import 'video_autoplay.dart';

/// A video in a post.
///  - The cached thumbnail shows instantly; no player exists yet.
///  - When the video is mostly on screen (and this is the current page of the post),
///    the player starts, muted and looping.
///  - When it leaves the screen it pauses; two seconds later the player is released,
///    so nothing keeps decoding while it is not visible.
///  - When another page is opened on top (for example the post detail page opened by
///    "Comment"), the video underneath pauses and only the video on top plays.
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

class _VideoTileState extends State<VideoTile> {
  VideoPlayerController? _controller;
  bool _starting = false;
  double _fraction = 0;
  Timer? _releaseTimer;

  /// False while another page is open on top of this one.
  bool _routeActive = true;
  bool _lastPlaying = false;

  /// The same post can be on screen twice (feed + post detail page). Each tile gets
  /// its own id, so one can never switch the other one off.
  late final String _uid = '${widget.tileId}@${identityHashCode(this)}';

  VideoAutoplay get _auto => VideoAutoplay.instance;
  bool get _shouldPlay => widget.pageActive && _routeActive && _auto.isActive(_uid);

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _auto.removeListener(_sync);
    _auto.muted.removeListener(_applyMute);
    _auto.remove(_uid);
    _releaseTimer?.cancel();
    _controller?.removeListener(_onPlayerChanged);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _report() {
    final visible = widget.pageActive && _routeActive;
    _auto.report(_uid, visible ? _fraction : 0);
  }

  void _applyMute() {
    _controller?.setVolume(_auto.muted.value ? 0 : 1);
    if (mounted) setState(() {});
  }

  /// Redraws when the player really starts or stops, so the picture never stays
  /// frozen on the thumbnail while the sound keeps going.
  void _onPlayerChanged() {
    final c = _controller;
    if (c == null || !mounted) return;
    final playing = c.value.isInitialized && c.value.isPlaying;
    if (c.value.hasError) {
      c.removeListener(_onPlayerChanged);
      c.dispose();
      _controller = null;
      _lastPlaying = false;
      setState(() {});
      return;
    }
    if (playing != _lastPlaying) {
      _lastPlaying = playing;
      setState(() {});
    }
  }

  void _sync() {
    if (!mounted) return;
    if (_shouldPlay) {
      _releaseTimer?.cancel();
      _play();
    } else {
      _controller?.pause();
      _scheduleRelease();
    }
  }

  Future<void> _play() async {
    if (_starting) return;
    var c = _controller;
    if (c == null) {
      _starting = true;
      c = VideoPlayerController.file(
        File(widget.item.path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = c;
      try {
        await c.initialize();
        await c.setLooping(true);
        await c.setVolume(_auto.muted.value ? 0 : 1);
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
    }
    // The video may have scrolled away (or a page opened on top) while it was starting.
    if (_shouldPlay && mounted) {
      await c.play();
      if (mounted) setState(() {});
    } else {
      await c.pause();
    }
  }

  void _scheduleRelease() {
    _releaseTimer?.cancel();
    if (_controller == null) return;
    _releaseTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _shouldPlay || _starting) return;
      _controller?.removeListener(_onPlayerChanged);
      _controller?.dispose();
      _controller = null;
      _lastPlaying = false;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = _controller;
    final playing = c != null && c.value.isInitialized && c.value.isPlaying;

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
            // 2. The player fades in once it is really playing.
            if (c != null && c.value.isInitialized)
              AnimatedOpacity(
                opacity: playing ? 1 : 0,
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


