import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'add_story_screen.dart';
import 'composer_screen.dart';

/// Small menu that slides up from the + button.
void showCreateSheet(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, _, __) {
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 84),
            child: _CreateMenu(
              onPosts: () {
                Navigator.pop(dialogContext);
                Navigator.of(context).push(composerRoute());
              },
              onGroups: () => Navigator.pop(dialogContext),
              onStory: () {
                Navigator.pop(dialogContext);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddStoryScreen()),
                );
              },
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            alignment: Alignment.bottomRight,
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class _CreateMenu extends StatelessWidget {
  final VoidCallback onPosts;
  final VoidCallback onGroups;
  final VoidCallback onStory;

  const _CreateMenu({
    required this.onPosts,
    required this.onGroups,
    required this.onStory,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: (MediaQuery.of(context).size.width - 48).clamp(160.0, 210.0).toDouble(),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CreateItem(icon: LucideIcons.newspaper, label: 'Posts', onTap: onPosts),
            _CreateItem(icon: LucideIcons.users, label: 'Groups', onTap: onGroups),
            _CreateItem(icon: LucideIcons.circlePlus, label: 'Add story', onTap: onStory),
          ],
        ),
      ),
    );
  }
}

class _CreateItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CreateItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.black, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



