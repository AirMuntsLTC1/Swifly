import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../responsive.dart';
import '../supabase_config.dart';

const Color kAuthBlue = Color(0xFF1D6FDC);
const Color kAuthGrey = Color(0xFF8E8E8E);
const Color kAuthField = Color(0xFFF2F2F2);

final RegExp kEmailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp kUsernamePattern = RegExp(r'^[a-z0-9_.]{3,30}$');

/// Shared page layout for Sign in, Register, Forgot password and Verify.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showLogo;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showLogo = false,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: showBack
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: Colors.black,
            )
          : null,
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 480,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              r.pad,
              r.h(showBack ? 8 : 40),
              r.pad,
              MediaQuery.of(context).viewInsets.bottom + r.h(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLogo) ...[
                  Container(
                    width: r.s(64),
                    height: r.s(64),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(r.s(18)),
                    ),
                    child: Icon(LucideIcons.flaskConical, color: Colors.white, size: r.s(32)),
                  ),
                  SizedBox(height: r.h(24)),
                ],
                Text(title,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.black)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: const TextStyle(fontSize: 15, color: kAuthGrey, height: 1.35)),
                SizedBox(height: r.h(24)),
                if (!kSupabaseConfigured) const _SetupBanner(),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Supabase is not connected yet. Paste your Project URL and anon key into lib/supabase_config.dart.',
        style: TextStyle(color: Color(0xFF8A5A00), fontSize: 13),
      ),
    );
  }
}

/// Rounded grey text field. Set [password] to get a show / hide eye.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool password;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.password = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.password && _hide,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        autofillHints: widget.autofillHints,
        inputFormatters: widget.inputFormatters,
        textCapitalization: widget.textCapitalization,
        autocorrect: false,
        enableSuggestions: !widget.password,
        style: const TextStyle(fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: kAuthGrey),
          filled: true,
          fillColor: kAuthField,
          prefixIcon: Icon(widget.icon, size: 20, color: kAuthGrey),
          suffixIcon: widget.password
              ? IconButton(
                  icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: kAuthGrey),
                  onPressed: () => setState(() => _hide = !_hide),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.black, width: 1.2),
          ),
        ),
      ),
    );
  }
}

/// Full-width blue pill button with a spinner while [loading].
class AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthButton({super.key, required this.label, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAuthBlue,
          disabledBackgroundColor: kAuthBlue.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: EdgeInsets.symmetric(vertical: r.h(15)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Red error line. Takes no space when [text] is empty.
class AuthError extends StatelessWidget {
  final String? text;
  const AuthError(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = text;
    if (t == null || t.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, size: 16, color: Color(0xFFD93025)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t, style: const TextStyle(color: Color(0xFFD93025), fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// Small blue text link.
class AuthLink extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const AuthLink(this.text, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: TextStyle(
                color: onTap == null ? kAuthGrey : kAuthBlue,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ),
    );
  }
}
