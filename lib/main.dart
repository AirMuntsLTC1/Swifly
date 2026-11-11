import 'package:flutter/material.dart';

import 'inbox_store.dart';
import 'notification_banner.dart';
import 'notification_router.dart';
import 'splash_screen.dart';

void main() {
  NotificationBanner.init();
  runApp(const SocialApp());
  LiveEvents.start();
}

class SocialApp extends StatelessWidget {
  const SocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifly',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
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
