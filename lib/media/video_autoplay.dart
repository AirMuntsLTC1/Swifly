import 'dart:async';

import 'package:flutter/foundation.dart';

/// Decides which video in the feed plays. Only one video plays at a time: the one
/// that is most on screen, and only when at least [playThreshold] of it is visible.
/// Every other video is paused.
class VideoAutoplay extends ChangeNotifier {
  VideoAutoplay._();
  static final VideoAutoplay instance = VideoAutoplay._();

  static const double playThreshold = 0.6;

  /// Videos start muted, like most feeds. Tapping a video flips this for all of them.
  final ValueNotifier<bool> muted = ValueNotifier<bool>(true);

  final Map<String, double> _fractions = {};
  String? _winner;
  bool _scheduled = false;

  bool isActive(String id) => _winner == id;

  /// [fraction] is how much of the video (0 to 1) is on screen. 0 removes it.
  void report(String id, double fraction) {
    if (fraction <= 0) {
      _fractions.remove(id);
    } else {
      _fractions[id] = fraction;
    }
    if (_scheduled) return;
    _scheduled = true;
    // Decide after the current frame, so tiles never rebuild in the middle of a build.
    scheduleMicrotask(() {
      _scheduled = false;
      _recompute();
    });
  }

  void remove(String id) => report(id, 0);

  void _recompute() {
    String? best;
    double bestFraction = 0;
    _fractions.forEach((id, f) {
      if (f > bestFraction) {
        best = id;
        bestFraction = f;
      }
    });
    if (bestFraction < playThreshold) best = null;

    // Keep the current video unless another one is clearly more visible.
    final current = _winner;
    if (current != null && best != null && current != best) {
      final cf = _fractions[current] ?? 0;
      if (cf >= playThreshold && cf >= bestFraction - 0.15) best = current;
    }

    if (best != _winner) {
      _winner = best;
      notifyListeners();
    }
  }
}



