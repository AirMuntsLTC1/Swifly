import 'package:flutter/material.dart';

/// Small red count bubble (unread messages, notifications, requests).
/// It always wraps its text: exactly one line tall, never stretched by its
/// parent, and it scales gently with the screen width so it fits every phone.
class CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final Color? borderColor;
  final int maxShown;

  const CountBadge({
    super.key,
    required this.count,
    this.color = const Color(0xFFFF3B30),
    this.borderColor,
    this.maxShown = 9,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.15).toDouble();
    final size = 18.0 * scale;
    final label = count > maxShown ? '$maxShown+' : '$count';
    // Align with size factors makes the badge shrink-wrap its content even when the
    // parent (a Row, a Stack, a chip) offers a lot of free height or width.
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      child: IgnorePointer(
        child: Container(
          constraints: BoxConstraints(minWidth: size, minHeight: size),
          padding: EdgeInsets.symmetric(horizontal: 5 * scale),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size),
            border: borderColor == null ? null : Border.all(color: borderColor!, width: 1.5),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11 * scale,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}



