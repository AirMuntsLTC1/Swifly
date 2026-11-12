import 'package:flutter/material.dart';

import 'typing_store.dart';

/// "Liam Park is commenting" with three bouncing dots. Takes no space when nobody is typing.
class TypingIndicator extends StatefulWidget {
  final String postId;
  const TypingIndicator({super.key, required this.postId});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  String _label(List<String> names) {
    if (names.length == 1) return '${names[0]} is commenting';
    if (names.length == 2) return '${names[0]} and ${names[1]} are commenting';
    return '${names[0]} and ${names.length - 1} others are commenting';
  }

  Widget _dot(int i) {
    return AnimatedBuilder(
      animation: _dots,
      builder: (context, _) {
        // Each dot starts a little later than the one before it, so they bounce in turn.
        final phase = (_dots.value + i * 0.2) % 1.0;
        final up = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
        return Transform.translate(
          offset: Offset(0, -3 * up),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF8E8E8E),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TypingStore.instance,
      builder: (context, _) {
        final names = TypingStore.instance.namesFor(widget.postId);
        if (names.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  _label(names),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (int i = 0; i < 3; i++) _dot(i),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}


