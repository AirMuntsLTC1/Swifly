import 'package:flutter/material.dart';

import '../app_bootstrap.dart';
import '../auth_service.dart';
import '../home_screen.dart';
import 'sign_in_screen.dart';

Route<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    );

/// Call after a successful login / register / password reset.
/// Loads this user's data, then opens Home and clears the sign-in screens.
Future<void> completeSignIn(BuildContext context) async {
  final nav = Navigator.of(context);
  AuthService.instance.applyUser();
  await loadAppData();
  startLiveActivity();
  nav.pushAndRemoveUntil(_fade(const HomeScreen()), (_) => false);
}

/// Signs out, wipes this user's data from memory and returns to Sign in.
Future<void> logOut(BuildContext context) async {
  final nav = Navigator.of(context);
  await AuthService.instance.signOut();
  await clearAppData();
  nav.pushAndRemoveUntil(_fade(const SignInScreen()), (_) => false);
}

/// First screen after the splash.
Widget startScreen() => AuthService.instance.needsLogin ? const SignInScreen() : const HomeScreen();
