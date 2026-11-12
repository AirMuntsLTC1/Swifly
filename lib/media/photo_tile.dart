import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'media_item.dart';
import 'preview_image.dart';

/// A photo in a post. The small cached thumbnail is drawn first (instant), and the
/// cached full photo fades in on top as soon as it has decoded.
class PhotoTile extends StatelessWidget {
  final MediaItem item;
  const PhotoTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PreviewImage(path: item.previewPath, cacheWidth: 240),
        Image.file(
          File(item.path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 900,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: child,
            );
          },
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(LucideIcons.image, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}


