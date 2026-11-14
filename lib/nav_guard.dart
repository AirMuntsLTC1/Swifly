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

/// Pushes [route]. Ignores the tap only when the screen on top already has the
/// same route name (the same screen opened twice). It used to also drop every
/// tap made within 350 ms of an earlier push, which is why taps needed repeating.
Future<T?> pushOnce<T>(BuildContext context, Route<T> route) {
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
  return nav.push<T>(route);
}
