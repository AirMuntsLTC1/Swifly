import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dm_theme.dart';

/// One "New followers" row in Messages. It slides and fades in when it appears,
/// and the hand waves.
class NewConnectionRow extends StatelessWidget {
  final String handle;
  final DmColors c;
  final VoidCallback onTap;

  const NewConnectionRow({super.key, required this.handle, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(28 * (1 - t), 0), child: child),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              DmAvatar(handle: handle, name: dmName(handle), size: 50, ring: hasUnseenStory(handle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dmName(handle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('New follower · say hi', style: TextStyle(color: c.sub, fontSize: 13)),
                  ],
                ),
              ),
              const _WaveHand(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveHand extends StatefulWidget {
  const _WaveHand();

  @override
  State<_WaveHand> createState() => _WaveHandState();
}

class _WaveHandState extends State<_WaveHand> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.rotate(angle: 0.35 * math.sin(_c.value * math.pi * 2), child: child),
      child: const Text('👋', style: TextStyle(fontSize: 22)),
    );
  }
}

/// Animated "hi" stickers above the composer. Shown only in a new conversation,
/// until the first message is sent. Tapping one sends it.
class HiStickerStrip extends StatefulWidget {
  final ValueChanged<String> onPick;
  const HiStickerStrip({super.key, required this.onPick});

  @override
  State<HiStickerStrip> createState() => _HiStickerStripState();
}

class _HiStickerStripState extends State<HiStickerStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  static const List<(String, String, Color)> _stickers = [
    ('👋', 'Hi!', Color(0xFFFFE8CC)),
    ('🙋', 'Hey there', Color(0xFFDDF4FF)),
    ('😊', 'Nice to meet you', Color(0xFFE6F9E9)),
    ('🤗', 'Hello!', Color(0xFFF3E8FF)),
    ('✨', 'Hi friend', Color(0xFFFFF7D6)),
    ('🌞', 'Good day!', Color(0xFFFFEFD6)),
    ('🫶', 'Hi, how are you?', Color(0xFFFFE3EC)),
    ('👋🏽', 'Hi 😄', Color(0xFFE4F1FF)),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        itemCount: _stickers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (emoji, label, color) = _stickers[i];
          return AnimatedBuilder(
            animation: _c,
            // Each sticker is a little out of step with the next, so the row looks alive.
            builder: (context, child) {
              final phase = (_c.value + i * 0.13) % 1.0;
              final s = math.sin(phase * math.pi * 2);
              return Transform.translate(
                offset: Offset(0, -6 * s.abs()),
                child: Transform.rotate(angle: 0.12 * s, child: child),
              );
            },
            child: GestureDetector(
              onTap: () => widget.onPick('$emoji $label'),
              child: Container(
                width: 98,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
