import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'people_directory.dart';
import 'supabase_config.dart';

/// What the email-code-auth Edge Function answered.
class AuthResult {
  final bool ok;
  final String message;
  final int? retryAfter;
  final int? attemptsRemaining;
  final int resendAfter;
  final bool hasSession;

  const AuthResult({
    required this.ok,
    this.message = '',
    this.retryAfter,
    this.attemptsRemaining,
    this.resendAfter = 60,
    this.hasSession = false,
  });

  factory AuthResult.error(String message, {int? retryAfter, int? attemptsRemaining}) =>
      AuthResult(ok: false, message: message, retryAfter: retryAfter, attemptsRemaining: attemptsRemaining);

  factory AuthResult.fromJson(Map<String, dynamic> j, {bool hasSession = false}) {
    final ok = j['success'] == true;
    final text = ok ? (j['message'] ?? '') : (j['error'] ?? 'Something went wrong. Please try again.');
    return AuthResult(
      ok: ok,
      message: text.toString(),
      retryAfter: (j['retry_after'] as num?)?.toInt(),
      attemptsRemaining: (j['attempts_remaining'] as num?)?.toInt(),
      resendAfter: (j['resend_after'] as num?)?.toInt() ?? 60,
      hasSession: hasSession,
    );
  }
}

/// Talks to the `email-code-auth` Edge Function and keeps the Supabase session.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _function = 'email-code-auth';

  /// Call once at startup (main.dart). Does nothing while auth is switched off.
  static Future<void> init() async {
    if (!kAuthEnabled) return;
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  }

  SupabaseClient get client => Supabase.instance.client;

  /// Never throws: if Supabase has not started yet, the answer is "not signed in".
  bool get signedIn {
    if (!kAuthEnabled) return false;
    try {
      return client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  bool get needsLogin => kAuthEnabled && !signedIn;

  /// Copies the signed-in user's name and @username into [CurrentUser].
  void applyUser() {
    if (!kAuthEnabled) return;
    final u = client.auth.currentUser;
    if (u == null) return;
    final meta = u.userMetadata ?? const <String, dynamic>{};
    // The database stores usernames in lower case, so compare in lower case too.
    final username = (meta['username'] ?? u.email?.split('@').first ?? '').toString().toLowerCase();
    final display = (meta['display_name'] ?? '').toString().trim();
    CurrentUser.handle = '@$username';
    CurrentUser.name = display.isEmpty ? username : display;
  }

  Future<AuthResult> _call(Map<String, dynamic> body) async {
    try {
      final res = await client.functions.invoke(_function, body: body);
      final data = res.data;
      final json = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      var result = AuthResult.fromJson(json);
      final session = json['session'];
      if (result.ok && session is Map) {
        // The Edge Function already signed the user in and returned the full session.
        // Restoring it locally needs no extra network round trip (setSession did one,
        // which made every login wait longer).
        try {
          await client.auth.recoverSession(jsonEncode(session));
        } catch (_) {
          final refresh = session['refresh_token']?.toString() ?? '';
          if (refresh.isNotEmpty) await client.auth.setSession(refresh);
        }
        result = AuthResult.fromJson(json, hasSession: signedIn);
      }
      return result;
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map) return AuthResult.fromJson(Map<String, dynamic>.from(d));
      return AuthResult.error('The server could not be reached. Please try again.');
    } catch (_) {
      return AuthResult.error('No connection. Check your internet and try again.');
    }
  }

  Future<AuthResult> login(String email, String password) =>
      _call({'action': 'login', 'email': email, 'password': password});

  /// purpose: 'signup' or 'password_reset'. username / displayName only for signup.
  Future<AuthResult> sendCode(
    String email,
    String purpose, {
    String? username,
    String? displayName,
  }) =>
      _call({
        'action': 'send_code',
        'email': email,
        'purpose': purpose,
        if (username != null) 'username': username,
        if (displayName != null) 'display_name': displayName,
      });

  /// Checks the 6-digit code. For signup [password] is the new account password,
  /// for password_reset it is the new password.
  Future<AuthResult> verifyCode(String email, String purpose, String code, String password) =>
      _call({
        'action': 'verify_code',
        'email': email,
        'purpose': purpose,
        'code': code,
        'password': password,
      });

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (_) {}
  }
}
