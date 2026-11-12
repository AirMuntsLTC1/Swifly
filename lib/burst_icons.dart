import 'dart:math';

import 'package:flutter/material.dart';

/// Shows small icons that float up and fade out each time [trigger] changes.
class BurstIcons extends StatefulWidget {
  final int trigger;
  final IconData icon;
  final Color color;
  final int count;

  const BurstIcons({
    super.key,
    required this.trigger,
    required this.icon,
    required this.color,
    this.count = 8,
  });

  @override
  State<BurstIcons> createState() => _BurstIconsState();
}

class _Particle {
  final double dx;
  final double size;
  final double delay;
  final double rise;

  const _Particle(this.dx, this.size, this.delay, this.rise);
}

class _BurstIconsState extends State<BurstIcons> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final Random _random = Random();
  List<_Particle> _particles = const [];

  @override
  void didUpdateWidget(covariant BurstIcons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      _particles = List.generate(
        widget.count,
        (_) => _Particle(
          (_random.nextDouble() * 2 - 1) * 26,
          9 + _random.nextDouble() * 7,
          _random.nextDouble() * 0.25,
          46 + _random.nextDouble() * 22,
        ),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  Widget _particle(_Particle p) {
    final t = _clamp01((_controller.value - p.delay) / (1 - p.delay));
    if (t <= 0) return const SizedBox.shrink();
    return Transform.translate(
      offset: Offset(p.dx * t, -p.rise * Curves.easeOut.transform(t)),
      child: Opacity(
        opacity: 1 - t,
        child: Icon(widget.icon, size: p.size, color: widget.color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [for (final p in _particles) _particle(p)],
          );
        },
      ),
    );
  }
}
