import os
import shutil

def apply_fix(filepath, old_text, new_text, description):
    if not os.path.exists(filepath):
        print(f"❌ Could not find {filepath}")
        return
    shutil.copyfile(filepath, filepath + ".bak")
    with open(filepath, 'r') as f:
        content = f.read()
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ Fixed: {description}")
    else:
        print(f"⚠️ Skipped: {description} (code already changed)")

print("Fixing App Startup, Timeout, and Search Layout...\n")

# --- FIX 1: Stop the app from getting stuck on the Flutter splash screen ---
apply_fix(
    "lib/main.dart",
    """  await AuthService.init();
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
  if (inApp) startLiveActivity();""",
    """  try {
    // 10-second max wait for login restoration
    await AuthService.init().timeout(const Duration(seconds: 10));
    if (!AuthService.instance.needsLogin) {
      AuthService.instance.applyUser();
    }
  } catch (e) {
    debugPrint('Startup error: $e');
  }
  
  ProfileStore.instance.loadFromDevice();
  LogoService.instance.load();
  RealtimeRouter.init();
  NotificationBanner.init();
  
  // Load the UI immediately so it never gets stuck on the Flutter logo
  runApp(const SocialApp());
  
  final inApp = !AuthService.instance.needsLogin;
  if (inApp) {
    // Load database in the background AFTER the UI is drawn
    loadAppData().then((_) => startLiveActivity());
  }
  MediaPipeline.instance.ensureReady().then((_) => MediaPipeline.instance.trimCache());""",
    "Fix stuck splash screen by moving database load to background"
)

# --- FIX 2: Increase the 12-second timeout that causes "Server took too long" ---
apply_fix(
    "lib/app_bootstrap.dart",
    """      await job().timeout(const Duration(seconds: 12));""",
    """      await job().timeout(const Duration(seconds: 30));""",
    "Increase database timeout to 30 seconds"
)

# --- FIX 3: Fix the stretched text in the Search / Discover Screen ---
# Replace ListTile with a constrained Row so text doesn't stack vertically
apply_fix(
    "lib/discover_panel.dart",
    """    return ListTile(
      onTap: () => pushOnce(context, UserProfileScreen.route(f)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: const CircleAvatar(
        backgroundColor: Colors.black,
        child: Icon(LucideIcons.user, color: Colors.white, size: 20),
      ),
      title: Text(f.name,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: Colors.black)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(f.handle, style: const TextStyle(color: Color(0xFF8E8E8E))),
          const SizedBox(height: 3),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              '${NativeCore.formatCount(followers)} followers · '
              '${NativeCore.formatCount(following)} following',
              key: ValueKey('$followers-$following'),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
            ),
          ),
        ],
      ),
      trailing: FollowButton(handle: f.handle, compact: true),
    );""",
    """    return InkWell(
      onTap: () => pushOnce(context, UserProfileScreen.route(f)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.black,
              child: Icon(LucideIcons.user, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(f.handle, 
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF8E8E8E))),
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Text(
                      '${NativeCore.formatCount(followers)} followers · '
                      '${NativeCore.formatCount(following)} following',
                      key: ValueKey('$followers-$following'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FollowButton(handle: f.handle, compact: true),
          ],
        ),
      ),
    );""",
    "Fix stretched text in Discover screen"
)

print("\nAll fixes applied! You can now rebuild the app.")
