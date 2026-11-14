import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import 'auth_widgets.dart';
import 'verify_code_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim().toLowerCase();
    if (!kEmailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await AuthService.instance.sendCode(email, 'password_reset');
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
          purpose: 'password_reset',
          resendAfter: res.resendAfter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot password?',
      subtitle: "Enter your email and we'll send you a 6-digit code to reset it.",
      children: [
        AuthField(
          controller: _email,
          hint: 'Email',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          onSubmitted: (_) => _submit(),
        ),
        AuthError(_error),
        const SizedBox(height: 4),
        AuthButton(label: 'Send code', loading: _busy, onPressed: _submit),
        const SizedBox(height: 12),
        Center(child: AuthLink('Back to sign in', onTap: _busy ? null : () => Navigator.of(context).pop())),
      ],
    );
  }
}
