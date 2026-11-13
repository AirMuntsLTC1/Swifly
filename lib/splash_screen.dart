import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'auth/auth_flow.dart';
import 'app_bootstrap.dart';
import 'auth_service.dart';
import 'post_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  String _status = 'Connecting to Swifly...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await AuthService.init().timeout(const Duration(seconds: 10));
      if (!AuthService.instance.needsLogin) {
        AuthService.instance.applyUser();
        setState(() => _status = 'Loading your feed...');
        await PostStore.instance.loadCache(); // Load offline cache instantly
        await loadAppData();
      }
    } catch (e) {
      debugPrint('Init Error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, animation, secondaryAnimation) => startScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 112, height: 112,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 10))]),
                child: const Icon(LucideIcons.flaskConical, color: Colors.white, size: 56),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Swifly', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.black)),
            const SizedBox(height: 6),
            Text('Connect. Share. Inspire.', style: TextStyle(fontSize: 14, color: Colors.black.withValues(alpha: 0.5))),
            const SizedBox(height: 48),
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black)),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
          ],
        ),
      ),
    );
  }
}
