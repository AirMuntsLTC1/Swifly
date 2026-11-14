import 'package:flutter/material.dart';

import 'dm_theme.dart';
import 'people_directory.dart';

/// One person in a list: avatar, name, @handle, and an optional action button.
///
/// The text column is wrapped in Expanded, so it always gets the space left over.
/// Long names are cut with "..." on one line. They never squeeze into a narrow column.
class PersonRow extends StatelessWidget {
  final Person person;
  final Widget? trailing;
  final Widget? subtitle;
  final VoidCallback? onTap;
  final double avatarSize;

  const PersonRow({
    super.key,
    required this.person,
    this.trailing,
    this.subtitle,
    this.onTap,
    this.avatarSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    final p = person;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            DmAvatar(handle: p.handle, name: p.name, size: avatarSize),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF8E8E8E)),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
