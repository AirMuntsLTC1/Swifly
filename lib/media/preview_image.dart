import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Shows a local preview image, or a grey box if there is none (yet).
/// Shared by photos, video thumbnails and the composer strip.
class PreviewImage extends StatelessWidget {
  final String? path;
  final int cacheWidth;
  final IconData placeholderIcon;

  const PreviewImage({
    super.key,
    required this.path,
    this.cacheWidth = 800,
    this.placeholderIcon = LucideIcons.image,
  });

  Widget _placeholder() => Container(
        color: const Color(0xFFF2F2F2),
        alignment: Alignment.center,
        child: Icon(placeholderIcon, color: Colors.grey),
      );

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || p.isEmpty) return _placeholder();
    return Image.file(
      File(p),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }
}
