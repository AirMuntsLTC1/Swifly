import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The messenger that shows every app message (set on MaterialApp in main.dart).
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Shows one short message at the bottom. Replaces the one before it.
void showAppMessage(String text) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 4),
    ));
}

/// Turns an error into a short sentence the person can understand.
String errorText(Object error) {
  if (error is TimeoutException) {
    return 'The server took too long. Check your internet connection.';
  }
  if (error is StateError) {
    return error.message.toString();
  }
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final text = error.message.toLowerCase();
    if (code == '42501' || text.contains('row-level security')) {
      return 'The database blocked this (security rules).';
    }
    if (code == 'PGRST301' || text.contains('jwt')) {
      return 'Your sign-in expired. Sign in again.';
    }
    return error.message;
  }
  if (error is AuthException) {
    return error.message;
  }
  final text = error.toString();
  return text.length > 140 ? '${text.substring(0, 140)}...' : text;
}

/// Writes the full error to the log and shows the reason on screen.
void reportError(String what, Object error) {
  debugPrint('[Swifly] $what: $error');
  showAppMessage('$what: ${errorText(error)}');
}
