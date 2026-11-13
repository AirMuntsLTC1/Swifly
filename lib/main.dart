import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'app_feedback.dart';
import 'media/media_pipeline.dart';
import 'logo_service.dart';
import 'notification_banner.dart';
import 'notification_router.dart';
import 'profile_store.dart';
import 'realtime_router.dart';
import 'supabase_realtime.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 120);
  
  ProfileStore.instance.loadFromDevice();
  LogoService.instance.load();
  RealtimeRouter.init();
  NotificationBanner.init();
  SupabaseRealtime.instance.initLifecycle();
  
  runApp(const SocialApp());
  MediaPipeline.instance.ensureReady().then((_) => MediaPipeline.instance.trimCache());
}

class SocialApp extends StatelessWidget {
  const SocialApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifly', navigatorKey: appNavigatorKey, scaffoldMessengerKey: appMessengerKey,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.black, brightness: Brightness.light), scaffoldBackgroundColor: Colors.white),
      home: const SplashScreen(),
    );
  }
}
