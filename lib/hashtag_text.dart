import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'hashtag_screen.dart';

const Color kHashtagBlue = Color(0xFF1D6FDC);

/// Text where every #hashtag is blue and tappable.
class HashtagText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;

  const HashtagText(
    this.text, {
    super.key,
    this.style = const TextStyle(fontSize: 14, color: Colors.black),
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  State<HashtagText> createState() => _HashtagTextState();
}

class _HashtagTextState extends State<HashtagText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _spans() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final text = widget.text;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in RegExp(r'#[a-zA-Z0-9_]+').allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final tag = m.group(0)!;
      final rec = TapGestureRecognizer()
        ..onTap = () {
          if (mounted) HashtagScreen.navigate(context, tag.toLowerCase());
        };
      _recognizers.add(rec);
      spans.add(TextSpan(
        text: tag,
        style: const TextStyle(color: kHashtagBlue, fontWeight: FontWeight.w600),
        recognizer: rec,
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(style: widget.style, children: _spans()),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
