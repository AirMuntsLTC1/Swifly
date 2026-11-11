import 'package:flutter/material.dart';

import 'app_config.dart';
import 'mock_data.dart';
import 'mock_realtime.dart';
import 'notification_banner.dart';
import 'notification_router.dart';
import 'realtime_router.dart';
import 'splash_screen.dart';

void main() {
  if (kUseMockData) loadMockData();
  RealtimeRouter.init();
  NotificationBanner.init();
  runApp(const SocialApp());
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
