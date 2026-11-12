#!/data/data/com.termux/files/usr/bin/bash
# Run from the Swifly project folder:  bash /path/to/apply_fixes.sh
# Put video_tile.dart, build_php_android.sh and build-apk.yml next to this script.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -d lib ] || { echo "Run this inside the swifly project folder (the one with lib/)"; exit 1; }

cp "$HERE/video_tile.dart"        lib/media/video_tile.dart
cp "$HERE/build_php_android.sh"   tools/build_php_android.sh
cp "$HERE/build-apk.yml"          .github/workflows/build-apk.yml

# Unused imports (flutter analyze fails on these)
sed -i "/import 'package:flutter\/foundation.dart';/d" lib/database_service.dart
sed -i "/import 'post_model.dart';/d"                  lib/inbox_store.dart
sed -i "/import 'post_model.dart';/d"                  lib/user_profile_screen.dart
sed -i "/import 'native_bridge.dart';/d"               lib/profile_details_section.dart
sed -i "/import 'dart:async';/d"                       lib/media/media_pipeline.dart

# Icon name that newer lucide_icons_flutter versions renamed
sed -i "s/LucideIcons.checkCircle2/LucideIcons.circleCheck/" lib/home_screen.dart

echo "Done. Now run:"
echo "  git add . && git commit -m 'Fix video freeze and build errors' && git push"
