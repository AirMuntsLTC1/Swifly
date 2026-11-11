import 'dart:async';

import 'app_config.dart';
import 'post_model.dart';
import 'realtime.dart';

/// Simulates other people's activity by publishing events into [Realtime].
/// Delete this file when the real database is connected. Its only job is to
/// publish events, so nothing else depends on it.
class MockRealtime {
  static const Duration interval = Duration(seconds: 15);
  static Timer? _timer;
  static int _step = 0;

  static void start() {
    if (!kUseMockData || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => _runNext());
  }

  static void _runNext() {
    final steps = <void Function()>[
      _like,
      _comment,
      _reply,
      _save,
      _follow,
      _unfollow,
      _message,
      _storyReact,
      _tag,
    ];
    steps[_step % steps.length]();
    _step++;
  }

  static void _publish(RealtimeEvent e) => Realtime.instance.publish(e);

  static void _like() {
    _publish(const PostLikedEvent(
      postId: kMyPostId,
      actorName: 'Ava Stone',
      actorHandle: '@avastone',
    ));
  }

  /// Shows the typing indicator first, then the comment arrives.
  static void _comment() {
    _publish(const TypingEvent(
      postId: kMyPostId,
      actorName: 'Liam Park',
      actorHandle: '@liampark',
      isTyping: true,
    ));
    Timer(const Duration(milliseconds: 2500), () {
      _publish(CommentAddedEvent(
        postId: kMyPostId,
        id: 'mock-c${DateTime.now().microsecondsSinceEpoch}',
        actorName: 'Liam Park',
        actorHandle: '@liampark',
        text: 'Congrats on the new post!',
      ));
    });
  }

  static void _reply() {
    _publish(CommentAddedEvent(
      postId: kMyPostId,
      id: 'mock-r${DateTime.now().microsecondsSinceEpoch}',
      parentId: 'demo-c1',
      actorName: 'Noah Reed',
      actorHandle: '@noahreed',
      text: 'Thanks Liam, appreciate it!',
    ));
  }

  static void _save() {
    _publish(const PostSavedEvent(
      postId: kMyPostId,
      actorName: 'Mia Chen',
      actorHandle: '@miachen',
    ));
  }

  static void _follow() {
    _publish(const FollowedEvent(
      actorName: 'Omar Khalid',
      actorHandle: '@omarkh',
    ));
  }

  static void _unfollow() {
    _publish(const UnfollowedEvent(
      actorName: 'Omar Khalid',
      actorHandle: '@omarkh',
    ));
  }

  static void _message() {
    _publish(const MessageEvent(
      actorName: 'Sofia Lopez',
      actorHandle: '@sofial',
      text: 'Are we still on for Saturday?',
    ));
  }

  static void _storyReact() {
    _publish(const StoryReactionEvent(
      actorName: 'Max Turner',
      actorHandle: '@maxturner',
      emoji: '❤️',
    ));
  }

  static void _tag() {
    _publish(const TagEvent(
      postId: kMyPostId,
      actorName: 'Kai Ramzy',
      actorHandle: '@kairamzy',
    ));
  }
}
