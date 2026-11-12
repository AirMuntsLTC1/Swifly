import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'media_item.dart';
import 'preview_image.dart';

/// Small square preview used in the composer's selected-media strip.
/// Videos get a play badge and their length once PHP has read it.
class MediaThumb extends StatelessWidget {
  final MediaItem item;
  const MediaThumb({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PreviewImage(
          path: item.previewPath,
          cacheWidth: 240,
          placeholderIcon: item.isVideo ? LucideIcons.video : LucideIcons.image,
        ),
        if (item.isVideo)
          const Center(
            child: Icon(LucideIcons.play, color: Colors.white, size: 26),
          ),
        if (item.isVideo && item.durationMs > 0)
          Positioned(
            left: 6,
            bottom: 5,
            child: Text(
              item.durationLabel,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        if (item.processing)
          const Positioned(
            right: 6,
            bottom: 6,
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
