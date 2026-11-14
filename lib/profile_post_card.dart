import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'post_model.dart';

/// One post on a profile, in the same style on your own profile and on other
/// people's: the picture (if any) on top, the text, then the like, comment and time row.
class ProfilePostCard extends StatelessWidget {
  final Post post;
  const ProfilePostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final media = post.media.isNotEmpty ? post.media.first : null;
    final preview = media?.previewPath;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(
                File(preview),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF2F2F2)),
              ),
            ),
          if (post.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Text(
                post.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black, fontSize: 15),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                const Icon(LucideIcons.heart, size: 14, color: Color(0xFF8E8E8E)),
                const SizedBox(width: 4),
                Text('${post.likes}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
                const SizedBox(width: 14),
                const Icon(LucideIcons.messageCircle, size: 14, color: Color(0xFF8E8E8E)),
                const SizedBox(width: 4),
                Text('${post.totalComments}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
                const Spacer(),
                Text(post.timeLabel,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
