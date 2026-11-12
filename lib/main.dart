import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'app_config.dart';
import 'media/media_pipeline.dart';
import 'mock_data.dart';
import 'mock_realtime.dart';
import 'notification_banner.dart';
import 'notification_router.dart';
import 'realtime_router.dart';
import 'splash_screen.dart';

void main() {
  // Check how much of a video is on screen about 8 times a second.
  VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 120);
  if (kUseMockData) loadMockData();
  RealtimeRouter.init();
  NotificationBanner.init();
  runApp(const SocialApp());
  // Unpack the PHP media scripts and trim the local media cache in the background.
  MediaPipeline.instance.ensureReady().then((_) => MediaPipeline.instance.trimCache());
  if (kUseMockData) MockRealtime.start();
}

class SocialApp extends StatelessWidget {
  const SocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifly',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      // Keeps text and layout the same size on every phone, even when the phone's
      // font size setting is very large or very small.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.05,
        child: child!,
      ),
      theme: ThemeData(
        useMaterial3: true,
        textTheme: _appTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}

/// Facebook-style type: bold titles and names, grey secondary text.
/// Widgets that set their own TextStyle keep it; this covers everything else.
TextTheme _appTextTheme() {
  return ThemeData.light().textTheme
      .apply(bodyColor: Colors.black, displayColor: Colors.black)
      .copyWith(
        titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
        bodyMedium: const TextStyle(fontSize: 15, color: Colors.black),
        bodySmall: const TextStyle(fontSize: 13, color: Color(0xFF65676B)),
      );
}
