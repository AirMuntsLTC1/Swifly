import 'package:flutter/material.dart';

import 'database_service.dart';
import 'follow_store.dart';
import 'native_bridge.dart';

/// "12 followers · 3 following" for one person, read from their profile in the database.
/// Refreshes when you follow or unfollow someone.
class FollowCountsLine extends StatefulWidget {
  final String handle;
  final TextStyle style;
  const FollowCountsLine({super.key, required this.handle, required this.style});

  @override
  State<FollowCountsLine> createState() => _FollowCountsLineState();
}

class _FollowCountsLineState extends State<FollowCountsLine> {
  int? _followers;
  int? _following;

  @override
  void initState() {
    super.initState();
    _load();
    FollowStore.instance.addListener(_load);
  }

  @override
  void didUpdateWidget(covariant FollowCountsLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) _load();
  }

  @override
  void dispose() {
    FollowStore.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await DatabaseService.instance.fetchProfileCounts(widget.handle);
      if (!mounted) return;
      setState(() {
        _followers = c['followers'] ?? 0;
        _following = c['following'] ?? 0;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final f = _followers;
    final g = _following;
    if (f == null || g == null) {
      return Text('… followers · … following', style: widget.style);
    }
    return Text(
      '${NativeCore.formatCount(f)} followers · ${NativeCore.formatCount(g)} following',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}
