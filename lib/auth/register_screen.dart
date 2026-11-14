import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import 'auth_widgets.dart';
import 'verify_code_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    final username = _username.text.trim().toLowerCase();
    final email = _email.text.trim().toLowerCase();
    final password = _password.text;

    String? problem;
    if (name.isEmpty) {
      problem = 'Enter your name.';
    } else if (name.length > 60) {
      problem = 'Your name is too long.';
    } else if (!kUsernamePattern.hasMatch(username)) {
      problem = 'Username must be 3–30 letters, numbers, dots or underscores.';
    } else if (!kEmailPattern.hasMatch(email)) {
      problem = 'Enter a valid email address.';
    } else if (password.length < 8 || password.length > 128) {
      problem = 'Password must be between 8 and 128 characters.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await AuthService.instance.sendCode(
      email,
      'signup',
      username: username,
      displayName: name,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      setState(() => _error = res.message);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerifyCodeScreen(
          email: email,
          purpose: 'signup',
          password: password,
          username: username,
          displayName: name,
          resendAfter: res.resendAfter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create account',
      subtitle: "We'll email you a 6-digit code to confirm it's you.",
      children: [
        AuthField(
          controller: _name,
          hint: 'Full name',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
        ),
        AuthField(
          controller: _username,
          hint: 'Username',
          icon: Icons.alternate_email,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_.]')),
            LengthLimitingTextInputFormatter(30),
          ],
        ),
        AuthField(
          controller: _email,
          hint: 'Email',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        ),
        AuthField(
          controller: _password,
          hint: 'Password (8+ characters)',
          icon: Icons.lock_outline,
          password: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _submit(),
        ),
        AuthError(_error),
        const SizedBox(height: 4),
        AuthButton(label: 'Send code', loading: _busy, onPressed: _submit),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Already have an account? ', style: TextStyle(color: kAuthGrey, fontSize: 14)),
            AuthLink('Sign in', onTap: _busy ? null : () => Navigator.of(context).pop()),
          ],
        ),
      ],
    );
  }
}
