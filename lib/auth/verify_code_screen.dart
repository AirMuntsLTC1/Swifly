import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import 'auth_flow.dart';
import 'auth_widgets.dart';

/// Step 2 for both Register (purpose 'signup') and Forgot password ('password_reset').
/// Signup already has its password from the Register screen. Reset asks for a new one here.
class VerifyCodeScreen extends StatefulWidget {
  final String email;
  final String purpose;
  final String? password;
  final String? username;
  final String? displayName;
  final int resendAfter;

  const VerifyCodeScreen({
    super.key,
    required this.email,
    required this.purpose,
    this.password,
    this.username,
    this.displayName,
    this.resendAfter = 60,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  Timer? _timer;
  int _cooldown = 0;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _info;

  bool get _isReset => widget.purpose == 'password_reset';

  @override
  void initState() {
    super.initState();
    _startCooldown(widget.resendAfter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown - 1);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    if (_resending || _cooldown > 0) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    final res = await AuthService.instance.sendCode(
      widget.email,
      widget.purpose,
      username: widget.username,
      displayName: widget.displayName,
    );
    if (!mounted) return;
    setState(() => _resending = false);
    if (res.ok) {
      setState(() => _info = 'A new code was sent.');
      _startCooldown(res.resendAfter);
    } else {
      setState(() => _error = res.message);
      if (res.retryAfter != null) _startCooldown(res.retryAfter!);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final code = _code.text.trim();
    final password = _isReset ? _newPassword.text : (widget.password ?? '');

    String? problem;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      problem = 'Enter the six-digit code from your email.';
    } else if (password.length < 8 || password.length > 128) {
      problem = 'Password must be between 8 and 128 characters.';
    } else if (_isReset && password != _confirm.text) {
      problem = 'The two passwords do not match.';
    }
    if (problem != null) {
      setState(() {
        _error = problem;
        _info = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final res = await AuthService.instance.verifyCode(widget.email, widget.purpose, code, password);
    if (!mounted) return;

    if (res.ok && res.hasSession) {
      await completeSignIn(context);
      return;
    }
    if (res.ok) {
      // Password was changed but the automatic sign in did not happen.
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message.isEmpty ? 'Password updated. Please sign in.' : res.message)),
      );
      return;
    }
    setState(() {
      _busy = false;
      final left = res.attemptsRemaining;
      _error = left == null ? res.message : '${res.message} ($left ${left == 1 ? "attempt" : "attempts"} left)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _isReset ? 'Reset password' : 'Check your email',
      subtitle: 'We sent a 6-digit code to ${widget.email}. It expires in 10 minutes.',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textInputAction: _isReset ? TextInputAction.next : TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: (_) {
              if (!_isReset) _submit();
            },
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 12),
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: const TextStyle(color: Color(0xFFBDBDBD), letterSpacing: 12),
              filled: true,
              fillColor: kAuthField,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.black, width: 1.2),
              ),
            ),
          ),
        ),
        if (_isReset) ...[
          AuthField(
            controller: _newPassword,
            hint: 'New password (8+ characters)',
            icon: Icons.lock_outline,
            password: true,
            autofillHints: const [AutofillHints.newPassword],
          ),
          AuthField(
            controller: _confirm,
            hint: 'Confirm new password',
            icon: Icons.lock_outline,
            password: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
        AuthError(_error),
        if (_info != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_info!, style: const TextStyle(color: Color(0xFF1E8E3E), fontSize: 14)),
          ),
        const SizedBox(height: 4),
        AuthButton(label: _isReset ? 'Reset password' : 'Verify and create account', loading: _busy, onPressed: _submit),
        const SizedBox(height: 12),
        Center(
          child: AuthLink(
            _cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code',
            onTap: (_cooldown > 0 || _resending || _busy) ? null : _resend,
          ),
        ),
      ],
    );
  }
}

