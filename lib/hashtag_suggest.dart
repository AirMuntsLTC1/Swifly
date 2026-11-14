import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'database_service.dart';
import 'hashtag_text.dart';
import 'native_bridge.dart';
import 'post_model.dart';

/// One hashtag suggestion: how many posts and how many comments use it.
class HashtagHit {
  final String tag;
  final int posts;
  final int comments;
  const HashtagHit(this.tag, this.posts, this.comments);

  int get total => posts + comments;
}

/// Finds hashtags that start with what was typed, and counts how many posts
/// and comments use each one. Reads the database, or the phone's copy when offline.
class HashtagIndex {
  static final RegExp _tag = RegExp(r'#([A-Za-z0-9_]+)');

  static Future<List<HashtagHit>> suggest(String prefix) async {
    final p = prefix.toLowerCase();
    List<String> postTexts;
    List<String> commentTexts;
    try {
      final t = await DatabaseService.instance.hashtagTexts(p);
      postTexts = t.posts;
      commentTexts = t.comments;
    } catch (_) {
      postTexts = [for (final post in PostStore.instance.ranked) post.text];
      commentTexts = [for (final post in PostStore.instance.ranked) ..._commentTexts(post.comments)];
    }

    final postsCount = <String, int>{};
    final commentsCount = <String, int>{};
    _count(postTexts, p, postsCount);
    _count(commentTexts, p, commentsCount);

    final tags = {...postsCount.keys, ...commentsCount.keys};
    final hits = [
      for (final t in tags) HashtagHit(t, postsCount[t] ?? 0, commentsCount[t] ?? 0),
    ];
    hits.sort((a, b) => b.total != a.total ? b.total - a.total : a.tag.compareTo(b.tag));
    return hits.take(8).toList();
  }

  /// Counts each matching tag once per text, so one post never counts twice.
  static void _count(List<String> texts, String prefix, Map<String, int> into) {
    for (final text in texts) {
      final tags = <String>{};
      for (final m in _tag.allMatches(text)) {
        final t = m.group(1)!.toLowerCase();
        if (t.startsWith(prefix)) tags.add(t);
      }
      for (final t in tags) {
        into[t] = (into[t] ?? 0) + 1;
      }
    }
  }

  static Iterable<String> _commentTexts(Iterable<CommentItem> items) sync* {
    for (final c in items) {
      yield c.text;
      yield* _commentTexts(c.replies);
    }
  }
}

/// Watches a text field. When the text before the cursor ends in #word, it looks up
/// matching hashtags. Picking one replaces the #word with the full tag.
class HashtagAssist extends ChangeNotifier {
  final TextEditingController controller;
  HashtagAssist(this.controller) {
    controller.addListener(_onText);
  }

  static final RegExp _tail = RegExp(r'#([A-Za-z0-9_]*)$');

  bool active = false;
  bool loading = false;
  List<HashtagHit> hits = const [];

  String _query = '';
  int _ticket = 0;
  Timer? _debounce;

  void _onText() {
    final q = _tailQuery();
    if (q == null) {
      if (active) {
        active = false;
        hits = const [];
        _debounce?.cancel();
        notifyListeners();
      }
      return;
    }
    if (!active || q != _query) {
      _query = q;
      active = true;
      notifyListeners();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () => _load(q));
    }
  }

  String? _tailQuery() {
    final text = controller.text;
    final caret = controller.selection.baseOffset;
    if (caret < 0 || caret > text.length) return null;
    return _tail.firstMatch(text.substring(0, caret))?.group(1);
  }

  Future<void> _load(String q) async {
    final ticket = ++_ticket;
    loading = true;
    notifyListeners();
    final result = await HashtagIndex.suggest(q);
    if (ticket != _ticket) return;
    loading = false;
    hits = result;
    notifyListeners();
  }

  /// Replaces the #word before the cursor with the chosen hashtag and a space.
  void pick(HashtagHit hit) {
    final text = controller.text;
    final caret = controller.selection.baseOffset;
    if (caret < 0 || caret > text.length) return;
    final m = _tail.firstMatch(text.substring(0, caret));
    if (m == null) return;
    final insert = '#${hit.tag} ';
    controller.value = TextEditingValue(
      text: text.substring(0, m.start) + insert + text.substring(caret),
      selection: TextSelection.collapsed(offset: m.start + insert.length),
    );
  }

  @override
  void dispose() {
    controller.removeListener(_onText);
    _debounce?.cancel();
    super.dispose();
  }
}

/// The suggestion panel. It sits above the text field and does not cover the
/// text, so typing carries on normally.
class HashtagSuggestPanel extends StatelessWidget {
  final HashtagAssist assist;
  const HashtagSuggestPanel({super.key, required this.assist});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: assist,
      builder: (context, _) {
        if (!assist.active) return const SizedBox.shrink();
        final hits = assist.hits;
        final listHeight = (hits.length * 56.0).clamp(0.0, 280.0);
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAEAEA)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Row(
                  children: [
                    const Icon(LucideIcons.hash, size: 16, color: kHashtagBlue),
                    const SizedBox(width: 6),
                    const Text('Hashtags',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black)),
                    const Spacer(),
                    if (assist.loading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      ),
                  ],
                ),
              ),
              if (hits.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: Text(
                    assist.loading ? 'Searching…' : 'No hashtags yet. Keep typing to make a new one.',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E)),
                  ),
                )
              else
                SizedBox(
                  height: listHeight,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 6),
                    children: [
                      for (final h in hits)
                        InkWell(
                          onTap: () => assist.pick(h),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('#${h.tag}',
                                          style: const TextStyle(
                                              color: kHashtagBlue, fontWeight: FontWeight.w800, fontSize: 15)),
                                      Text(
                                        '${NativeCore.formatCount(h.posts)} posts · '
                                        '${NativeCore.formatCount(h.comments)} comments',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(LucideIcons.plus, size: 16, color: Color(0xFF8E8E8E)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
