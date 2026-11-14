import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import 'auth_flow.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim().toLowerCase();
    final password = _password.text;
    if (!kEmailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await AuthService.instance.login(email, password);
    if (!mounted) return;
    if (res.ok && res.hasSession) {
      await completeSignIn(context);
      return;
    }
    setState(() {
      _busy = false;
      _error = res.ok ? 'Could not start your session. Please try again.' : res.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: false,
      showLogo: true,
      title: 'Welcome back',
      subtitle: 'Sign in to continue to Swifly.',
      children: [
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
          hint: 'Password',
          icon: Icons.lock_outline,
          password: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: AuthLink(
            'Forgot password?',
            onTap: _busy
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim())),
                    ),
          ),
        ),
        AuthError(_error),
        const SizedBox(height: 4),
        AuthButton(label: 'Sign in', loading: _busy, onPressed: _submit),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Don't have an account? ", style: TextStyle(color: kAuthGrey, fontSize: 14)),
            AuthLink(
              'Create one',
              onTap: _busy
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
            ),
          ],
        ),
      ],
    );
  }
}
