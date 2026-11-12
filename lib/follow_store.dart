import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'tag_friends_screen.dart';

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

/// Follow relationships for the signed-in user.
///
/// This is the ONLY place follow state lives. Screens listen to it and call
/// [follow] / [unfollow]. When the real database is connected:
///   1. Load the lists in [load] from the database.
///   2. [follow] and [unfollow] already call DatabaseService.toggleFollow.
///   3. Realtime "someone followed you" events call [applyIncomingFollow].
class FollowStore extends ChangeNotifier {
  FollowStore._();
  static final FollowStore instance = FollowStore._();

  final Set<String> _following = <String>{};
  final Set<String> _followers = <String>{};

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

  /// Replaces both lists. Called with mock data now, database results later.
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
    notifyListeners();
  }

  /// Updates immediately, then rolls back if the database rejects it.
  Future<void> follow(String handle) async {
    if (!_following.add(handle)) return;
    notifyListeners();
    try {
      await DatabaseService.instance.toggleFollow(handle, true);
    } catch (_) {
      _following.remove(handle);
      notifyListeners();
    }
  }

  Future<void> unfollow(String handle) async {
    if (!_following.remove(handle)) return;
    notifyListeners();
    try {
      await DatabaseService.instance.toggleFollow(handle, false);
    } catch (_) {
      _following.add(handle);
      notifyListeners();
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
}

/// Name and handle for a handle. Uses sample people for now.
/// When the database is connected, replace the body with a user lookup.
Person personFor(String handle) {
  for (final p in kPeople) {
    if (p.handle == handle) return p;
  }
  return Person(handle.replaceFirst('@', ''), handle);
}


