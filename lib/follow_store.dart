import 'package:flutter/foundation.dart';

import 'app_feedback.dart';
import 'database_service.dart';
import 'people_directory.dart';

/// How the signed-in user and another person follow each other.
enum FollowState { none, follower, following, mutual }

/// The label shown on every follow button in the app.
/// none -> Follow, they follow you -> Follow back, you follow them -> Following.
String followLabel(FollowState s) => switch (s) {
      FollowState.none => 'Follow',
      FollowState.follower => 'Follow back',
      FollowState.following => 'Following',
      FollowState.mutual => 'Following',
    };

/// Follow relationships for the signed-in user. The only place follow state lives.
///
/// Changes show at once. The database is then asked again, so the labels always
/// match the server. If the server refuses a change, it is undone and the
/// reason is shown.
class FollowStore extends ChangeNotifier {
  FollowStore._();
  static final FollowStore instance = FollowStore._();

  final Set<String> _following = <String>{};
  final Set<String> _followers = <String>{};

  /// Changes the user just made (handle -> true follow, false unfollow), kept
  /// until the server confirms them, so a late reload cannot undo them.
  final Map<String, bool> _pending = <String, bool>{};

  /// Handles you follow.
  Set<String> get followingHandles => Set.unmodifiable(_following);

  /// Handles that follow you.
  Set<String> get followerHandles => Set.unmodifiable(_followers);

  bool isFollowing(String handle) => _following.contains(handle);
  bool isFollower(String handle) => _followers.contains(handle);

  FollowState stateOf(String handle) {
    final you = isFollowing(handle);
    final them = isFollower(handle);
    if (you && them) return FollowState.mutual;
    if (you) return FollowState.following;
    if (them) return FollowState.follower;
    return FollowState.none;
  }

  /// Replaces both lists. Pending changes are applied on top.
  void load({
    Set<String> following = const <String>{},
    Set<String> followers = const <String>{},
  }) {
    _following
      ..clear()
      ..addAll(following);
    _followers
      ..clear()
      ..addAll(followers);
    _pending.forEach((handle, wanted) {
      if (wanted) {
        _following.add(handle);
      } else {
        _following.remove(handle);
      }
    });
    notifyListeners();
  }

  /// Reloads both lists from the database. Use this whenever a follow list opens.
  Future<void> refresh() async {
    try {
      final f = await DatabaseService.instance.fetchFollows();
      load(
        following: (f['following'] ?? const <String>[]).toSet(),
        followers: (f['followers'] ?? const <String>[]).toSet(),
      );
    } catch (_) {}
  }

  Future<void> follow(String handle) async {
    if (handle == kMeHandle || _following.contains(handle)) return;
    _following.add(handle);
    _pending[handle] = true;
    notifyListeners();
    await _send(handle, follow: true);
  }

  Future<void> unfollow(String handle) async {
    if (handle == kMeHandle || !_following.contains(handle)) return;
    _following.remove(handle);
    _pending[handle] = false;
    notifyListeners();
    await _send(handle, follow: false);
  }

  Future<void> _send(String handle, {required bool follow}) async {
    try {
      await DatabaseService.instance.toggleFollow(handle, follow);
      _pending.remove(handle);
      await refresh();
    } catch (e) {
      _pending.remove(handle);
      if (follow) {
        _following.remove(handle);
      } else {
        _following.add(handle);
      }
      notifyListeners();
      reportError(follow ? "Couldn't follow" : "Couldn't unfollow", e);
    }
  }

  /// Someone started following you (from realtime).
  void applyIncomingFollow(String handle) {
    if (_followers.add(handle)) notifyListeners();
  }

  /// Someone stopped following you (from realtime).
  void applyIncomingUnfollow(String handle) {
    if (_followers.remove(handle)) notifyListeners();
  }

  /// People you can suggest: not you, not followed by you, and not following you.
  /// Anyone you follow or who follows you is left out of every suggestion list.
  List<Person> suggestedPeople() => [
        for (final p in kPeople)
          if (p.handle != kMeHandle && stateOf(p.handle) == FollowState.none) p,
      ];
}

/// Name and handle for a handle, from the people directory.
Person personFor(String handle) {
  for (final p in kPeople) {
    if (p.handle == handle) return p;
  }
  return Person(handle.replaceFirst('@', ''), handle);
}
