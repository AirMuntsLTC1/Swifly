import 'package:flutter/material.dart';

/// Light, fast page route: a short slide with no full-screen fade, which is
/// much cheaper to draw on mid-range phones than the default transitions.
Route<T> fastRoute<T>({required Widget child, String? name}) {
  return PageRouteBuilder<T>(
    settings: RouteSettings(name: name),
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, animation, __, page) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.25, 0), end: Offset.zero)
            .animate(curved),
        child: page,
      );
    },
  );
}

DateTime? _lastPush;

/// Pushes [route] once. Ignores the tap when:
///  - another push happened less than 350 ms ago (fast double tap), or
///  - the screen on top already has the same route name (same screen twice).
Future<T?> pushOnce<T>(BuildContext context, Route<T> route) {
  final now = DateTime.now();
  if (_lastPush != null && now.difference(_lastPush!).inMilliseconds < 350) {
    return Future<T?>.value(null);
  }
  final nav = Navigator.of(context);
  final name = route.settings.name;
  if (name != null) {
    Route<dynamic>? top;
    nav.popUntil((r) {
      top = r;
      return true;
    });
    if (top?.settings.name == name) return Future<T?>.value(null);
  }
  _lastPush = now;
  return nav.push<T>(route);
}
