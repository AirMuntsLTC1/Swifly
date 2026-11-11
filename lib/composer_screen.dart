import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Expanding full-screen route: scales up from the center and
/// the rounded corners shrink to square as it opens.
Route<void> composerRoute() {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const ComposerScreen(),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          child: child,
          builder: (context, child) {
            final t = curved.value;
            return Transform.scale(
              scale: 0.82 + 0.18 * t,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28 * (1 - t)),
                child: child,
              ),
            );
          },
        ),
      );
    },
  );
}

class ComposerScreen extends StatefulWidget {
  const ComposerScreen({super.key});

  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen> {
  final TextEditingController _textController = TextEditingController();
  String _audience = 'Everyone';
  String? _tag;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _pickAudience() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final options = [
          (LucideIcons.globe, 'Everyone'),
          (LucideIcons.users, 'Followers'),
          (LucideIcons.lock, 'Only me'),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final o in options)
                  ListTile(
                    leading: Icon(o.$1, color: Colors.black),
                    title: Text(o.$2,
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.w600)),
                    trailing: _audience == o.$2
                        ? const Icon(LucideIcons.check, color: Colors.black)
                        : null,
                    onTap: () {
                      setState(() => _audience = o.$2);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTag() async {
    final controller = TextEditingController(text: _tag ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add tag',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          cursorColor: Colors.black,
          decoration: const InputDecoration(
            hintText: 'e.g. travel',
            prefixText: '#',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      setState(() => _tag = result.isEmpty ? null : result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar: close on the left, post button on the right
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, color: Colors.black),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Post',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAEAEA)),

            // Composer body: scrolls, and shrinks when the keyboard opens
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Your Name',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black)),
                              SizedBox(height: 2),
                              Text('@yourhandle',
                                  style: TextStyle(
                                      fontSize: 14, color: Color(0xFF8E8E8E))),
                            ],
                          ),
                        ),
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.black,
                          child: Icon(LucideIcons.user,
                              color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      autofocus: true,
                      maxLines: null,
                      cursorColor: Colors.black,
                      style: const TextStyle(
                          fontSize: 18, height: 1.4, color: Colors.black),
                      decoration: const InputDecoration(
                        hintText: "What's happening?",
                        hintStyle: TextStyle(color: Color(0xFF8E8E8E)),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Chip(
                          icon: LucideIcons.globe,
                          label: _audience,
                          trailing: LucideIcons.chevronDown,
                          onTap: _pickAudience,
                        ),
                        _Chip(
                          icon: LucideIcons.hash,
                          label: _tag == null ? 'Add tag' : '#$_tag',
                          onTap: _pickTag,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom toolbar: sits directly above the keyboard
            const Divider(height: 1, color: Color(0xFFEAEAEA)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Media',
                    onPressed: () {},
                    icon: const Icon(LucideIcons.image, color: Colors.black),
                  ),
                  IconButton(
                    tooltip: 'Emoji',
                    onPressed: () {},
                    icon: const Icon(LucideIcons.smile, color: Colors.black),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? trailing;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.black),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 16, color: Colors.black),
            ],
          ],
        ),
      ),
    );
  }
}
