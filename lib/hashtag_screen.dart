import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'feed_widgets.dart';
import 'native_bridge.dart';
import 'post_model.dart';

/// Full-screen page opened by tapping a trending hashtag.
Route<void> hashtagRoute(String tag) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => HashtagScreen(tag: tag),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position:
            Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                .animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class HashtagScreen extends StatelessWidget {
  final String tag;
  const HashtagScreen({super.key, required this.tag});

  static DateTime? _lastNavigated;

  static void navigate(BuildContext context, String tag) {
    final now = DateTime.now();
    if (_lastNavigated != null &&
        now.difference(_lastNavigated!).inMilliseconds < 600) {
      return;
    }
    _lastNavigated = now;
    Navigator.of(context).push(hashtagRoute(tag));
  }

  String get _label {
    final t = tag.replaceFirst('#', '');
    if (t.isEmpty) return tag;
    return t[0].toUpperCase() + t.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: ListenableBuilder(
        listenable: PostStore.instance,
        builder: (context, _) {
          final posts = PostStore.instance.postsWithHashtag(tag);
          final postLabel = posts.length == 1 ? 'post' : 'posts';

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 20, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(LucideIcons.arrowLeft,
                                    color: Colors.black),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _label,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8E8E8E),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF5FF),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    '${NativeCore.formatCount(posts.length)} $postLabel',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D6FDC),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (posts.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No posts with this hashtag yet',
                        style: TextStyle(color: Color(0xFF8E8E8E)),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => PostCard(
                      key: ValueKey(posts[i].id),
                      post: posts[i],
                    ),
                    childCount: posts.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}
