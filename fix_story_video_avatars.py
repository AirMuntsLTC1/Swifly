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

print("Applying Video Stories & Global Avatars Fixes...\n")

# ==========================================
# 1. STORY VIDEO SUPPORT (Models & Picker)
# ==========================================
apply_fix(
    "lib/story_models.dart",
    """  String? photoPath;
  double photoScale;""",
    """  String? photoPath;
  bool isVideo;
  double photoScale;""",
    "Added isVideo to StoryData model"
)

apply_fix(
    "lib/story_models.dart",
    """    this.bgColor = 0xFF1D6FDC,
    this.photoPath,
    this.photoScale = 1,""",
    """    this.bgColor = 0xFF1D6FDC,
    this.photoPath,
    this.isVideo = false,
    this.photoScale = 1,""",
    "Added isVideo to StoryData constructor"
)

apply_fix(
    "lib/story_models.dart",
    """        bgColor: bgColor,
        photoPath: photoPath,
        photoScale: photoScale,""",
    """        bgColor: bgColor,
        photoPath: photoPath,
        isVideo: isVideo,
        photoScale: photoScale,""",
    "Updated StoryData copy method"
)

apply_fix(
    "lib/add_story_screen.dart",
    """    final result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.image,
        themeColor: _brandBlue,
      ),
    );
    if (result == null || result.isEmpty) return;
    final file = await result.first.file;
    if (file != null && mounted) {
      setState(() {
        _data.photoPath = file.path;
        _data.resetPhotoTransform();
      });
    }""",
    """    final result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.common,
        themeColor: _brandBlue,
      ),
    );
    if (result == null || result.isEmpty) return;
    final asset = result.first;
    if (asset.type == AssetType.video && asset.duration > 50) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video must be 50 seconds or less')),
        );
      }
      return;
    }
    final file = await asset.file;
    if (file != null && mounted) {
      setState(() {
        _data.photoPath = file.path;
        _data.isVideo = asset.type == AssetType.video;
        _data.resetPhotoTransform();
      });
    }""",
    "Enabled video picking with 50s limit in AddStoryScreen"
)

# ==========================================
# 2. STORY VIDEO RENDERING
# ==========================================
apply_fix(
    "lib/story_widgets.dart",
    "import 'dart:io';\nimport 'dart:math' as math;",
    "import 'dart:io';\nimport 'dart:math' as math;\nimport 'package:video_player/video_player.dart';",
    "Added video_player import to story_widgets"
)

apply_fix(
    "lib/story_widgets.dart",
    """              child: Image.file(
                File(data.photoPath!),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),""",
    """              child: StoryMedia(data: data),""",
    "Replaced static image with StoryMedia widget"
)

# Append StoryMedia widget to the end of story_widgets.dart
with open("lib/story_widgets.dart", "a") as f:
    f.write("""

class StoryMedia extends StatefulWidget {
  final StoryData data;
  const StoryMedia({super.key, required this.data});
  @override
  State<StoryMedia> createState() => _StoryMediaState();
}

class _StoryMediaState extends State<StoryMedia> {
  VideoPlayerController? _controller;
  @override
  void initState() {
    super.initState();
    if (widget.data.isVideo && widget.data.photoPath != null) {
      _controller = VideoPlayerController.file(File(widget.data.photoPath!))
        ..initialize().then((_) {
          if (mounted) {
            _controller!.play();
            _controller!.setLooping(true);
            _controller!.setVolume(0);
            setState(() {});
          }
        });
    }
  }
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    if (widget.data.photoPath == null) return const SizedBox.shrink();
    if (widget.data.isVideo && _controller != null) {
      if (!_controller!.value.isInitialized) return const SizedBox.shrink();
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      );
    }
    return Image.file(
      File(widget.data.photoPath!),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
""")
print("✅ Fixed: Appended StoryMedia widget for video playback")

# ==========================================
# 3. STORY RING IN PROFILE TAB
# ==========================================
apply_fix(
    "lib/home_screen.dart",
    """        child: hasStory
            ? Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1D6FDC), width: 3),
                ),
                child: avatar,
              )
            : avatar,""",
    """        child: hasStory
            ? Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: kStoryRing,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: avatar,
                ),
              )
            : avatar,""",
    "Updated Profile story ring to gradient"
)

# ==========================================
# 4. AVATAR PERSISTENCE (DB & STORE)
# ==========================================
apply_fix(
    "lib/database_service.dart",
    """    final row = await _db
        .from('profiles')
        .select('id,username,display_name')
        .eq('id', id)
        .maybeSingle();""",
    """    final row = await _db
        .from('profiles')
        .select('id,username,display_name,avatar_url')
        .eq('id', id)
        .maybeSingle();""",
    "Fetch avatar_url in _who"
)

apply_fix(
    "lib/database_service.dart",
    """  const _Who({required this.id, required this.username, required this.name});

  factory _Who.fromRow(Map<String, dynamic> r) {
    final username = '${r['username'] ?? ''}';
    final display = '${r['display_name'] ?? ''}'.trim();
    return _Who(
      id: '${r['id'] ?? ''}',
      username: username,
      name: display.isEmpty ? username : display,
    );
  }""",
    """  final String? avatarUrl;
  const _Who({required this.id, required this.username, required this.name, this.avatarUrl});

  factory _Who.fromRow(Map<String, dynamic> r) {
    final username = '${r['username'] ?? ''}';
    final display = '${r['display_name'] ?? ''}'.trim();
    return _Who(
      id: '${r['id'] ?? ''}',
      username: username,
      name: display.isEmpty ? username : display,
      avatarUrl: r['avatar_url'] as String?,
    );
  }""",
    "Added avatarUrl to _Who class"
)

apply_fix(
    "lib/database_service.dart",
    """    return {
      'name': who.name,
      'display_name': who.name,
      'username': who.username,
      'handle': who.handle,
    };""",
    """    return {
      'name': who.name,
      'display_name': who.name,
      'username': who.username,
      'handle': who.handle,
      'avatar_url': who.avatarUrl,
    };""",
    "Return avatar_url in fetchMe"
)

apply_fix(
    "lib/database_service.dart",
    """  Future<void> uploadAvatar(String localPath) async {
    final me = _requireMe();
    final dot = localPath.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : localPath.substring(dot + 1).toLowerCase();
    final path = '$me/avatar.$ext';
    final storage = _db.storage.from('avatars');
    await storage.upload(path, File(localPath), fileOptions: const FileOptions(upsert: true));
    final url = storage.getPublicUrl(path);
    await _db.from('profiles').update({
      'avatar_url': '$url?v=${DateTime.now().millisecondsSinceEpoch}',
    }).eq('id', me);
  }""",
    """  Future<String> uploadAvatar(String localPath) async {
    final me = _requireMe();
    final dot = localPath.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : localPath.substring(dot + 1).toLowerCase();
    final path = '$me/avatar.$ext';
    final storage = _db.storage.from('avatars');
    await storage.upload(path, File(localPath), fileOptions: const FileOptions(upsert: true));
    final url = storage.getPublicUrl(path);
    final finalUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    await _db.from('profiles').update({
      'avatar_url': finalUrl,
    }).eq('id', me);
    return finalUrl;
  }""",
    "Make uploadAvatar return the URL"
)

apply_fix(
    "lib/profile_store.dart",
    """    avatarPath = path;
    notifyListeners();
    _saveToDevice();
    try {
      await DatabaseService.instance.uploadAvatar(path);
    } catch (_) {}""",
    """    avatarPath = path;
    notifyListeners();
    _saveToDevice();
    try {
      final remoteUrl = await DatabaseService.instance.uploadAvatar(path);
      avatarPath = remoteUrl;
      notifyListeners();
      _saveToDevice();
    } catch (e) {
      reportError('Avatar upload failed', e);
    }""",
    "Save remote URL after avatar upload"
)

apply_fix(
    "lib/profile_store.dart",
    """    await loadFromDevice();
    try {
      final rows = await DatabaseService.instance.fetchProfileFields();""",
    """    await loadFromDevice();
    try {
      final me = await DatabaseService.instance.fetchMe();
      if (me != null) {
        final remoteAvatar = me['avatar_url'] as String?;
        if (remoteAvatar != null && remoteAvatar.isNotEmpty) {
          avatarPath = remoteAvatar;
          notifyListeners();
        }
      }
      final rows = await DatabaseService.instance.fetchProfileFields();""",
    "Load remote avatar URL in loadFromDatabase"
)

# ==========================================
# 5. GLOBAL AVATARS (Google Initials)
# ==========================================
apply_fix(
    "lib/dm_theme.dart",
    """    final path = isMe ? ProfileStore.instance.avatarPath : null;
    final name = isMe ? kMeName : nameForHandle(handle);""",
    """    final path = isMe ? ProfileStore.instance.avatarPath : null;
    final name = isMe ? kMeName : nameForHandle(handle);
    final hasImage = path != null && path.isNotEmpty;""",
    "Prepare DmAvatar for NetworkImage"
)

apply_fix(
    "lib/dm_theme.dart",
    """        image: (path != null && File(path).existsSync())
            ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover)
            : null,""",
    """        image: hasImage
            ? DecorationImage(
                image: path.startsWith('http') 
                    ? NetworkImage(path) 
                    : FileImage(File(path)) as ImageProvider, 
                fit: BoxFit.cover)
            : null,""",
    "Update DmAvatar to support NetworkImage"
)

apply_fix(
    "lib/dm_theme.dart",
    """      child: (path != null && File(path).existsSync())
          ? null
          : Text(letter,""",
    """      child: !hasImage
          ? Text(letter,""",
    "Update DmAvatar fallback check"
)

# Replace CircleAvatar in Feed
apply_fix(
    "lib/feed_widgets.dart",
    "import 'people_directory.dart';",
    "import 'people_directory.dart';\nimport 'dm_theme.dart';",
    "Add dm_theme import to feed_widgets"
)
apply_fix(
    "lib/feed_widgets.dart",
    """        const CircleAvatar(
          radius: 20,
          backgroundColor: Colors.black,
          child: Icon(LucideIcons.user, color: Colors.white, size: 20),
        ),""",
    """        DmAvatar(handle: p.authorHandle, name: p.authorName, size: 40),""",
    "Use DmAvatar in Feed"
)

# Replace CircleAvatar in Search/Discover
apply_fix(
    "lib/discover_panel.dart",
    "import 'people_directory.dart';",
    "import 'people_directory.dart';\nimport 'dm_theme.dart';",
    "Add dm_theme import to discover_panel"
)
apply_fix(
    "lib/discover_panel.dart",
    """            const CircleAvatar(
              backgroundColor: Colors.black,
              child: Icon(LucideIcons.user, color: Colors.white, size: 20),
            ),""",
    """            DmAvatar(handle: f.handle, name: f.name, size: 40),""",
    "Use DmAvatar in Search"
)

# Replace CircleAvatar in Profile Suggestions
apply_fix(
    "lib/home_screen.dart",
    """            CircleAvatar(
              radius: r.s(30),
              backgroundColor: Colors.black,
              child: Icon(LucideIcons.user, color: Colors.white, size: r.s(30)),
            ),""",
    """            DmAvatar(handle: f.handle, name: f.name, size: r.s(60)),""",
    "Use DmAvatar in Profile Suggestions"
)

# Replace CircleAvatar in User Profile
apply_fix(
    "lib/user_profile_screen.dart",
    "import 'people_directory.dart';",
    "import 'people_directory.dart';\nimport 'dm_theme.dart';",
    "Add dm_theme import to user_profile_screen"
)
apply_fix(
    "lib/user_profile_screen.dart",
    """    final avatar = CircleAvatar(
      radius: r.s(44),
      backgroundColor: Colors.black,
      child: Icon(LucideIcons.user, color: Colors.white, size: r.s(40)),
    );""",
    """    final avatar = DmAvatar(handle: f.handle, name: f.name, size: r.s(88));""",
    "Use DmAvatar in User Profile"
)

# Replace CircleAvatar in Suggestions Screen
apply_fix(
    "lib/suggestions_screen.dart",
    "import 'people_directory.dart';",
    "import 'people_directory.dart';\nimport 'dm_theme.dart';",
    "Add dm_theme import to suggestions_screen"
)
apply_fix(
    "lib/suggestions_screen.dart",
    """            leading: const CircleAvatar(
              backgroundColor: Colors.black,
              child: Icon(LucideIcons.user, color: Colors.white),
            ),""",
    """            leading: DmAvatar(handle: p.handle, name: p.name, size: 40),""",
    "Use DmAvatar in Suggestions"
)

print("\nAll fixes applied successfully! You can now rebuild the app.")
