import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One place that decides how big things are, so the app fits any phone.
///
/// Design width is 390 (a normal phone). On a narrower phone everything shrinks a
/// little, on a wider phone or tablet it grows a little, never more than 15%.
/// Use it like:  `final r = R.of(context);  SizedBox(height: r.h(180))`
class R {
  final double width;
  final double height;
  final double scale;
  final EdgeInsets safe;

  const R._(this.width, this.height, this.scale, this.safe);

  factory R.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final s = (w / 390).clamp(0.85, 1.15).toDouble();
    return R._(w, mq.size.height, s, mq.padding);
  }

  /// Scales a size (width, padding, radius, icon) to this screen.
  double w(double v) => v * scale;

  /// Scales a height. Also gently follows screen height on short phones.
  double h(double v) {
    final shortFactor = (height / 800).clamp(0.9, 1.1).toDouble();
    return v * math.min(scale, shortFactor * 1.05);
  }

  /// Scales an icon or avatar size.
  double s(double v) => v * scale;

  bool get isSmall => width < 360;
  bool get isTablet => width >= 600;

  /// Page side padding.
  double get pad => w(20);
}

/// Keeps page content readable on tablets and foldables: content never gets
/// wider than [maxWidth] and is centred. On phones it changes nothing.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ContentWidth({super.key, required this.child, this.maxWidth = 640});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A row of items that wraps instead of overflowing on a narrow phone.
class FlexRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  const FlexRow({super.key, required this.children, this.spacing = 16, this.runSpacing = 8});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: spacing, runSpacing: runSpacing, children: children);
  }
}
