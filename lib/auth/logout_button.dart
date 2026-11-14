import 'package:flutter/material.dart';

import '../supabase_config.dart';
import 'auth_flow.dart';

/// "Log out" row for the profile tab. Shows nothing while sign in is switched off.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _ask(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('You can sign back in any time with your email and password.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: Color(0xFFD93025), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted) await logOut(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!kAuthEnabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => _ask(context),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFD93025)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          child: const Text('Log out',
              style: TextStyle(color: Color(0xFFD93025), fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
