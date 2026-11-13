import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dm_theme.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'post_model.dart';
import 'people_directory.dart';

const Color _blue = Color(0xFF1D6FDC);
const Color _grey = Color(0xFF8E8E8E);

PostRef postRefFor(Post p) {
  String? thumb;
  var video = false;
  if (p.media.isNotEmpty) {
    thumb = p.media.first.previewPath;
    video = p.media.first.isVideo;
  }
  return PostRef(postId: p.id, authorName: p.authorName, authorHandle: p.authorHandle, title: p.text.trim(), thumbPath: thumb, isVideo: video, mediaCount: p.media.length);
}

Future<void> showSharePostDialog(BuildContext context, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  final sent = await showGeneralDialog<int>(
    context: context, barrierDismissible: true, barrierLabel: 'Close', barrierColor: Colors.black.withValues(alpha: 0.45), transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => _ShareDialog(post: post),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1).animate(curved), child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved), child: child)));
    },
  );
  if (sent != null && sent > 0) {
    messenger..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(sent == 1 ? 'Post sent to 1 person' : 'Post sent to $sent people'), behavior: SnackBarBehavior.floating));
  }
}

class _ShareDialog extends StatefulWidget {
  final Post post;
  const _ShareDialog({required this.post});
  @override State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final Set<String> _selected = <String>{};
  final TextEditingController _note = TextEditingController();
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override void dispose() { _note.dispose(); _search.dispose(); super.dispose(); }

  List<String> _people() {
    final all = FollowStore.instance.followingHandles.where((h) => h != kMeHandle).toList()..sort((a, b) {
      final ma = FollowStore.instance.isFollower(a) ? 0 : 1; final mb = FollowStore.instance.isFollower(b) ? 0 : 1;
      if (ma != mb) return ma.compareTo(mb); return dmName(a).toLowerCase().compareTo(dmName(b).toLowerCase());
    });
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [for (final h in all) if (dmName(h).toLowerCase().contains(q) || h.toLowerCase().contains(q)) h];
  }

  void _send() {
    if (_selected.isEmpty) return;
    final ref = postRefFor(widget.post);
    final note = _note.text.trim();
    for (final h in _selected) { ChatStore.instance.send(h, note, post: ref); }
    PostStore.instance.registerShare(widget.post.id, _selected.length);
    Navigator.pop(context, _selected.length);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = (mq.size.width / 390).clamp(0.85, 1.15).toDouble();
    final p = widget.post;
    final caption = p.text.trim().isEmpty ? 'Photo or video post' : p.text.trim();
    
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom), // KEYBOARD FIX
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: mq.viewInsets.bottom > 0 ? 8 : 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440, maxHeight: mq.size.height * 0.78),
              child: Material(
                color: Colors.white, borderRadius: BorderRadius.circular(24), clipBehavior: Clip.antiAlias, elevation: 12,
                child: ListenableBuilder(
                  listenable: FollowStore.instance,
                  builder: (context, _) {
                    final people = _people();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                          child: Row(children: [
                            const Icon(LucideIcons.send, size: 20, color: Colors.black),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Share post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black))),
                            IconButton(icon: const Icon(LucideIcons.x, color: Colors.black), onPressed: () => Navigator.pop(context)),
                          ]),
                        ),
                        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Text('${p.authorName}: $caption', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: _grey))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _search, cursorColor: Colors.black, onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(hintText: 'Search people you follow', hintStyle: const TextStyle(color: _grey), prefixIcon: const Icon(LucideIcons.search, size: 18, color: _grey), isDense: true, filled: true, fillColor: const Color(0xFFF2F2F2), contentPadding: const EdgeInsets.symmetric(vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: people.isEmpty
                              ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Follow people to share posts with them', textAlign: TextAlign.center, style: TextStyle(color: _grey))))
                              : GridView.builder(
                                  shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 96 * s, mainAxisSpacing: 8, crossAxisSpacing: 4, mainAxisExtent: 62 * s + 8 + 4 + 18),
                                  itemCount: people.length,
                                  itemBuilder: (_, i) {
                                    final h = people[i]; final on = _selected.contains(h); final size = 62 * s;
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque, onTap: () => setState(() => on ? _selected.remove(h) : _selected.add(h)),
                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                        SizedBox(width: size + 8, height: size + 8, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                                          AnimatedScale(scale: on ? 0.9 : 1, duration: const Duration(milliseconds: 160), child: AnimatedContainer(duration: const Duration(milliseconds: 160), padding: const EdgeInsets.all(2.5), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? _blue : Colors.transparent, width: 2.5)), child: DmAvatar(handle: h, size: size - 8, gap: Colors.white))),
                                          Positioned(right: 0, bottom: 2, child: AnimatedScale(scale: on ? 1 : 0, duration: const Duration(milliseconds: 220), curve: Curves.elasticOut, child: Container(width: 22, height: 22, decoration: BoxDecoration(color: _blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(LucideIcons.check, size: 13, color: Colors.white)))),
                                        ])),
                                        const SizedBox(height: 4),
                                        Text(dmName(h), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Colors.black, fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
                                      ]),
                                    );
                                  },
                                ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEAEAEA)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                          child: Row(children: [
                            Expanded(child: TextField(controller: _note, maxLength: 150, cursorColor: Colors.black, decoration: InputDecoration(hintText: 'Add a message...', hintStyle: const TextStyle(color: _grey), counterText: '', isDense: true, filled: true, fillColor: const Color(0xFFF2F2F2), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
                            const SizedBox(width: 10),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200), height: 44,
                              decoration: BoxDecoration(color: _selected.isEmpty ? const Color(0xFFBDBDBD) : _blue, borderRadius: BorderRadius.circular(22)),
                              child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(22), onTap: _selected.isEmpty ? null : _send, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.send, size: 17, color: Colors.white), const SizedBox(width: 8), Text(_selected.isEmpty ? 'Send' : 'Send (${_selected.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))])))),
                            ),
                          ]),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
