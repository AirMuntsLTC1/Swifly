import 'package:flutter_test/flutter_test.dart';
import 'package:swifly/native_bridge.dart';

// Runs against the pure-Dart fallbacks (same results as cpp/swifly_core.cpp).
void main() {
  test('request / primary / general buckets', () {
    int b(bool f, bool r, bool a, int h, int u) => NativeCore.dmBucket(
        isFollowing: f, iReplied: r, accepted: a, hoursSinceLast: h, unread: u);
    expect(b(false, false, false, 1, 1), 1); // not followed, never replied
    expect(b(true, false, false, 1, 1), 0);
    expect(b(false, true, false, 1, 0), 0); // I replied
    expect(b(false, false, true, 1, 0), 0); // I accepted
    expect(b(true, false, false, 24 * 9, 0), 2); // quiet for 9 days
    expect(b(true, false, false, 24 * 9, 2), 0); // quiet but unread
  });

  test('filters need every selected flag', () {
    expect(NativeCore.dmFilterPass(1 | 2 | 8, 1 | 2), isTrue);
    expect(NativeCore.dmFilterPass(1, 1 | 2), isFalse);
    expect(NativeCore.dmFilterPass(0, 0), isTrue);
  });

  test('threads sort newest first and keep ties in order', () {
    expect(NativeCore.dmSortThreads([10, 50, 30, 50]), [1, 3, 2, 0]);
  });

  test('clip keeps whole characters', () {
    expect(NativeCore.dmClip('short', 20), 'short');
    expect(NativeCore.dmClip('Hello there\nfriend how are you doing', 20),
        'Hello there friend h...');
  });

  test('people who follow me come first', () {
    expect(NativeCore.dmRankPeople([false, true, false], [5, 0, 9]), [1, 2, 0]);
  });
}



