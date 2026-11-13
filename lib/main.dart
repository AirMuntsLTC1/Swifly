import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'app_feedback.dart';
import 'media/media_pipeline.dart';
import 'logo_service.dart';
import 'notification_banner.dart';
import 'notification_router.dart';
import 'profile_store.dart';
import 'realtime_router.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 120);
  
  ProfileStore.instance.loadFromDevice();
  LogoService.instance.load();
  RealtimeRouter.init();
  NotificationBanner.init();
  
  runApp(const SocialApp());
  
  MediaPipeline.instance.ensureReady().then((_) => MediaPipeline.instance.trimCache());
}

class SocialApp extends StatelessWidget {
  const SocialApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifly', navigatorKey: appNavigatorKey, scaffoldMessengerKey: appMessengerKey, debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery.withClampedTextScaling(minScaleFactor: 0.9, maxScaleFactor: 1.05, child: DefaultTextStyle.merge(style: const TextStyle(fontFamily: kAppFont), child: child!)),
      theme: ThemeData(
        useMaterial3: true, fontFamily: kAppFont, textTheme: _appTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black, brightness: Brightness.light),
        scaffoldBackgroundColor: Colors.white,
        snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF262626), elevation: 6, insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 28), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.35), actionTextColor: const Color(0xFF8AB4FF)),
      ),
      home: const SplashScreen(),
    );
  }
}

const String kAppFont = 'Roboto';
TextTheme _appTextTheme() {
  return ThemeData.light().textTheme.apply(bodyColor: Colors.black, displayColor: Colors.black).copyWith(titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black), titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black), bodyMedium: const TextStyle(fontSize: 15, color: Colors.black), bodySmall: const TextStyle(fontSize: 13, color: Color(0xFF65676B))).apply(fontFamily: kAppFont);
}
