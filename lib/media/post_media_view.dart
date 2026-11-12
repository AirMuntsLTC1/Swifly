import 'package:flutter/material.dart';

import 'media_item.dart';
import 'photo_tile.dart';
import 'video_tile.dart';

/// The media block of a post: one photo or video, or a swipe gallery mixing both.
/// Same square shape and dots as before; only the contents changed.
class PostMediaView extends StatefulWidget {
  final String postId;
  final List<MediaItem> media;

  const PostMediaView({super.key, required this.postId, required this.media});

  @override
  State<PostMediaView> createState() => _PostMediaViewState();
}

class _PostMediaViewState extends State<PostMediaView> {
  int _page = 0;

  Widget _tile(int i) {
    final item = widget.media[i];
    if (item.isVideo) {
      return VideoTile(
        key: ValueKey('${widget.postId}_video_$i'),
        item: item,
        tileId: '${widget.postId}#$i',
        pageActive: i == _page,
      );
    }
    return PhotoTile(key: ValueKey('${widget.postId}_photo_$i'), item: item);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.media.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: count == 1
            ? _tile(0)
            : Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    itemCount: count,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) => _tile(index),
                  ),
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          count,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _page == index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
