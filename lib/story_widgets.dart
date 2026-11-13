import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'story_models.dart';

const Color _brandBlue = Color(0xFF1D6FDC);

// ---------------------------------------------------------------------------
// Animated sticker
// ---------------------------------------------------------------------------

/// An emoji that moves (pulse, bounce, spin, float, wiggle, heartbeat, twinkle).
/// Drawn by Flutter, so it works offline and needs no downloads.
class AnimatedSticker extends StatefulWidget {
  final String emoji;
  final StickerMotion motion;
  final double size;
  const AnimatedSticker({
    super.key,
    required this.emoji,
    required this.motion,
    this.size = 64,
  });

  @override
  State<AnimatedSticker> createState() => _AnimatedStickerState();
}

class _AnimatedStickerState extends State<AnimatedSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final double _phase;

  @override
  void initState() {
    super.initState();
    _phase = (widget.emoji.runes.fold<int>(7, (a, b) => a * 31 + b) % 100) / 100;
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = (_c.value + _phase) % 1.0;
        final tau = 2 * math.pi * t;
        var m = Matrix4.identity();
        var opacity = 1.0;
        switch (widget.motion) {
          case StickerMotion.pulse:
            final k = 1 + 0.14 * math.sin(tau);
            m = Matrix4.identity()..scale(k, k, 1.0);
          case StickerMotion.bounce:
            final up = -math.sin(math.pi * t).abs() * s * 0.2;
            m = Matrix4.identity()..translate(0.0, up);
          case StickerMotion.spin:
            m = Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(tau);
          case StickerMotion.float:
            m = Matrix4.identity()
              ..translate(math.cos(tau) * s * 0.06, math.sin(tau) * s * 0.1)
              ..rotateZ(math.sin(tau) * 0.08);
          case StickerMotion.wiggle:
            m = Matrix4.identity()..rotateZ(math.sin(tau * 2) * 0.22);
          case StickerMotion.beat:
            final b = math.pow(math.sin(tau).abs(), 6).toDouble();
            final k = 1 + 0.26 * b;
            m = Matrix4.identity()..scale(k, k, 1.0);
          case StickerMotion.twinkle:
            final k = 0.92 + 0.14 * math.sin(tau);
            m = Matrix4.identity()
              ..rotateZ(math.sin(tau) * 0.12)
              ..scale(k, k, 1.0);
            opacity = 0.65 + 0.35 * ((math.sin(tau) + 1) / 2);
        }
        return Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.center,
            transform: m,
            child: Text(
              widget.emoji,
              style: TextStyle(fontSize: s, height: 1.1),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Story canvas (draws a StoryData, same everywhere)
// ---------------------------------------------------------------------------

/// Draws a story at a 9:16 ratio. Not interactive on its own; the editor adds
/// gestures on top and passes [layerKeys] so it can find each layer on screen.
class StoryCanvas extends StatelessWidget {
  final StoryData data;
  final bool showHint;
  final double radius;
  final Map<String, GlobalKey>? layerKeys;
  final String? hiddenLayerId;

  const StoryCanvas({
    super.key,
    required this.data,
    this.showHint = false,
    this.radius = 0,
    this.layerKeys,
    this.hiddenLayerId,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kStoryW / kStoryH,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: kStoryW,
            height: kStoryH,
            child: _content(),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(child: ColoredBox(color: Color(data.bgColor))),
        if (data.photoPath != null)
          Positioned.fill(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(data.photoDx * kStoryW, data.photoDy * kStoryH)
                ..rotateZ(data.photoRotation)
                ..scale(data.photoScale, data.photoScale, 1.0),
              child: Image.file(
                File(data.photoPath!),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        for (final l in data.layers) _layer(l),
        if (showHint && !data.layers.any((l) => l.kind == StoryLayerKind.text))
          const Positioned.fill(
            child: Center(
              child: Text(
                'Type your story',
                style: TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _layer(StoryLayer l) {
    const slotW = 320.0;
    const slotH = 240.0;
    final inner = KeyedSubtree(
      key: layerKeys?[l.id],
      child: _layerBody(l),
    );
    return Positioned(
      left: l.dx * kStoryW - slotW / 2,
      top: l.dy * kStoryH - slotH / 2,
      width: slotW,
      height: slotH,
      child: Center(
        child: Opacity(
          opacity: hiddenLayerId == l.id ? 0 : 1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateZ(l.rotation)
              ..scale(l.scale, l.scale, 1.0),
            child: inner,
          ),
        ),
      ),
    );
  }

  Widget _layerBody(StoryLayer l) {
    switch (l.kind) {
      case StoryLayerKind.text:
        final c = Color(l.color);
        final boxFg = c.computeLuminance() > 0.6 ? Colors.black : Colors.white;
        return Container(
          padding: l.boxed
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
              : EdgeInsets.zero,
          decoration: l.boxed
              ? BoxDecoration(color: c, borderRadius: BorderRadius.circular(12))
              : null,
          child: Text(
            l.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: l.boxed ? boxFg : c,
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w800,
              shadows: l.boxed
                  ? null
                  : const [Shadow(blurRadius: 8, color: Colors.black45)],
            ),
          ),
        );
      case StoryLayerKind.sticker:
        final def = stickerById(l.text);
        if (def == null) return const SizedBox.shrink();
        return AnimatedSticker(emoji: def.emoji, motion: def.motion, size: 72);
      case StoryLayerKind.place:
        return PlacePill(label: l.text);
    }
  }
}

/// White pill with a pin: "Zone 3, Brgy. Poblacion, Davao City".
class PlacePill extends StatelessWidget {
  final String label;
  const PlacePill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.mapPin, size: 18, color: _brandBlue),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded story preview (used in chat next to a reply).
class StoryThumb extends StatelessWidget {
  final StoryData data;
  final double width;
  final VoidCallback? onTap;
  const StoryThumb({super.key, required this.data, this.width = 96, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: StoryCanvas(data: data, radius: 13),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating hearts
// ---------------------------------------------------------------------------

class _Heart {
  final int id;
  final String emoji;
  final double startX; // fraction of width
  final double startY; // fraction of height
  final double size;
  final double drift;
  final int delayMs;
  final int durationMs;
  final bool big;
  const _Heart({
    required this.id,
    required this.emoji,
    required this.startX,
    required this.startY,
    required this.size,
    required this.drift,
    required this.delayMs,
    required this.durationMs,
    this.big = false,
  });
}

/// Put this on top of a story. Call [HeartBurstLayerState.burst] for hearts
/// floating up, or [HeartBurstLayerState.pop] for one big heart pop.
class HeartBurstLayer extends StatefulWidget {
  const HeartBurstLayer({super.key});

  @override
  State<HeartBurstLayer> createState() => HeartBurstLayerState();
}

class HeartBurstLayerState extends State<HeartBurstLayer> {
  final List<_Heart> _items = [];
  final math.Random _rng = math.Random();
  int _seq = 0;

  void burst({String emoji = '❤️', int count = 12, double x = 0.85, double y = 0.95}) {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < count; i++) {
        _items.add(_Heart(
          id: ++_seq,
          emoji: emoji,
          startX: (x + (_rng.nextDouble() - 0.5) * 0.18).clamp(0.05, 0.95),
          startY: y,
          size: 22 + _rng.nextDouble() * 22,
          drift: (_rng.nextDouble() - 0.5) * 90,
          delayMs: i * 70 + _rng.nextInt(80),
          durationMs: 1700 + _rng.nextInt(900),
        ));
      }
    });
  }

  void pop({String emoji = '❤️', double x = 0.5, double y = 0.5}) {
    if (!mounted) return;
    setState(() {
      _items.add(_Heart(
        id: ++_seq,
        emoji: emoji,
        startX: x,
        startY: y,
        size: 120,
        drift: 0,
        delayMs: 0,
        durationMs: 900,
        big: true,
      ));
    });
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _items.removeWhere((h) => h.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final h in _items)
              _FloatingHeart(
                key: ValueKey(h.id),
                heart: h,
                area: box.biggest,
                onDone: () => _remove(h.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingHeart extends StatefulWidget {
  final _Heart heart;
  final Size area;
  final VoidCallback onDone;
  const _FloatingHeart({
    super.key,
    required this.heart,
    required this.area,
    required this.onDone,
  });

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;
  late final double _phase;

  @override
  void initState() {
    super.initState();
    _phase = math.Random().nextDouble() * math.pi * 2;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.heart.durationMs),
    );
    Future.delayed(Duration(milliseconds: widget.heart.delayMs), () {
      if (!mounted) return;
      setState(() => _started = true);
      _c.forward().whenComplete(widget.onDone);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    final h = widget.heart;
    final a = widget.area;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        if (h.big) {
          final scale = t < 0.25
              ? Curves.easeOutBack.transform(t / 0.25) * 1.15
              : 1.15 - 0.15 * ((t - 0.25) / 0.75);
          final opacity = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
          return Positioned(
            left: h.startX * a.width - h.size / 2,
            top: h.startY * a.height - h.size / 2 - t * 40,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Text(h.emoji, style: TextStyle(fontSize: h.size)),
              ),
            ),
          );
        }
        final y = h.startY * a.height - t * a.height * 0.7;
        final x = h.startX * a.width +
            math.sin(t * math.pi * 3 + _phase) * 18 +
            h.drift * t;
        final scale = 0.4 + 0.8 * Curves.easeOutBack.transform(math.min(1.0, t * 3));
        final opacity = t < 0.7 ? 1.0 : ((1 - t) / 0.3).clamp(0.0, 1.0);
        return Positioned(
          left: x - h.size / 2,
          top: y - h.size / 2,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Text(h.emoji, style: TextStyle(fontSize: h.size)),
            ),
          ),
        );
      },
    );
  }
}



