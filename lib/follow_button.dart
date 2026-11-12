import 'package:flutter/material.dart';

import 'follow_store.dart';

const Color _brandBlue = Color(0xFF1D6FDC);

/// The one follow button used everywhere in the app.
/// Shows Follow, Follow back, or Following, and stays in sync with [FollowStore].
/// Tapping Following asks for confirmation before unfollowing.
class FollowButton extends StatelessWidget {
  final String handle;

  /// Fill the width of the parent (used on profile pages).
  final bool expand;

  /// Smaller size for lists and cards.
  final bool compact;

  const FollowButton({
    super.key,
    required this.handle,
    this.expand = false,
    this.compact = false,
  });

  Future<void> _onTap(BuildContext context, FollowState state) async {
    final store = FollowStore.instance;
    if (state == FollowState.following || state == FollowState.mutual) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Unfollow $handle?'),
          content: const Text("You won't see their posts in your feed."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Unfollow',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirmed == true) store.unfollow(handle);
    } else {
      store.follow(handle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FollowStore.instance,
      builder: (context, _) {
        final state = FollowStore.instance.stateOf(handle);
        final following =
            state == FollowState.following || state == FollowState.mutual;
        final label = followLabel(state);
        final height = compact ? 30.0 : 36.0;
        final fontSize = compact ? 13.0 : 14.0;

        return GestureDetector(
          onTap: () => _onTap(context, state),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: height,
            width: expand ? double.infinity : null,
            constraints: BoxConstraints(minWidth: compact ? 0 : 110),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
            decoration: BoxDecoration(
              color: following ? Colors.white : _brandBlue,
              borderRadius: BorderRadius.circular(compact ? 15 : 18),
              border: Border.all(
                color: following ? const Color(0xFFCCCCCC) : _brandBlue,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: following ? Colors.black : Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}


