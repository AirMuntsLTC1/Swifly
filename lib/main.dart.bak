import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'app_bootstrap.dart';
import 'app_feedback.dart';
import 'auth_service.dart';
import 'media/media_pipeline.dart';
import 'logo_service.dart';
import 'notification_banner.dart';
import 'notification_router.dart';
import 'profile_store.dart';
import 'realtime_router.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // If a part of a screen cannot be drawn, show the reason in its place
  // (instead of a blank area), so the problem can be seen and reported.
  ErrorWidget.builder = (details) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'This part could not be shown:\n${details.exceptionAsString()}',
          style: const TextStyle(color: Color(0xFF8A1C1C), fontSize: 12),
        ),
      );
  // Check how much of a video is on screen about 8 times a second.
  VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 120);
  // Sign in: starts Supabase and restores a saved login. Does nothing until
  // lib/supabase_config.dart is filled in.
  await AuthService.init();
  final inApp = !AuthService.instance.needsLogin;
  if (inApp) {
    AuthService.instance.applyUser();
    // Loads everything from Supabase.
    await loadAppData();
  }
  // Bring back the profile saved on this phone and the saved company/school logos.
  ProfileStore.instance.loadFromDevice();
  LogoService.instance.load();
  RealtimeRouter.init();
  NotificationBanner.init();
  runApp(const SocialApp());
  // Unpack the PHP media scripts and trim the local media cache in the background.
  MediaPipeline.instance.ensureReady().then((_) => MediaPipeline.instance.trimCache());
  if (inApp) startLiveActivity();
}

class SocialApp extends StatelessWidget {
  const SocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifly',
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      // Keeps text and layout the same size on every phone, even when the phone's
      // font size setting is very large or very small.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.05,
        // Roboto for every label, even text drawn outside a Material widget.
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: kAppFont),
          child: child!,
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: kAppFont,
        textTheme: _appTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        // Messages float above the bottom edge, with rounded corners and margins.
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF262626),
          elevation: 6,
          insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
          actionTextColor: const Color(0xFF8AB4FF),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Facebook-style type: bold titles and names, grey secondary text.
/// Widgets that set their own TextStyle keep it; this covers everything else.
/// One font for every label in the app.
const String kAppFont = 'Roboto';

TextTheme _appTextTheme() {
  return ThemeData.light().textTheme
      .apply(bodyColor: Colors.black, displayColor: Colors.black)
      .copyWith(
        titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
        bodyMedium: const TextStyle(fontSize: 15, color: Colors.black),
        bodySmall: const TextStyle(fontSize: 13, color: Color(0xFF65676B)),
      )
      .apply(fontFamily: kAppFont);
}



