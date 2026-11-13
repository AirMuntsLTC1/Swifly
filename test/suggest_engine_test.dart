import 'package:flutter_test/flutter_test.dart';
import 'package:swifly/suggest_engine.dart';

void main() {
  final service = SuggestService.instance;

  test('one letter lists the names that start with it first', () {
    final hits = service.searchLocal(SuggestKind.company, 'j', limit: 6);
    expect(hits.length, greaterThanOrEqualTo(3));
    for (final h in hits.take(3)) {
      expect(foldText(h.title).startsWith('j'), isTrue);
    }
  });

  test('the list narrows as more is typed', () {
    final hits = service.searchLocal(SuggestKind.company, 'goog');
    expect(hits.first.title, 'Google');
  });

  test('a later word can match', () {
    final hits = service.searchLocal(SuggestKind.company, 'america', limit: 20);
    expect(hits.any((h) => h.title == 'Bank of America'), isTrue);
  });

  test('a small typo still finds the name', () {
    final hits = service.searchLocal(SuggestKind.company, 'googel');
    expect(hits.first.title, 'Google');
  });

  test('cities are saved with their country', () {
    final hits = service.searchLocal(SuggestKind.place, 'lagos');
    expect(hits.first.value, 'Lagos, Nigeria');
  });

  test('picked items are not offered again', () {
    final hits = service.searchLocal(
      SuggestKind.hobby,
      'read',
      exclude: {'Reading'},
    );
    expect(hits.any((h) => h.title == 'Reading'), isFalse);
  });

  test('an empty box shows popular picks', () {
    final hits = service.searchLocal(SuggestKind.music, '', limit: 6);
    expect(hits.length, 6);
  });

  test('several values are joined and split back', () {
    final joined = joinMulti(['Hiking', 'Chess']);
    expect(splitMulti(joined), ['Hiking', 'Chess']);
  });

  test('position and company are saved together', () {
    final saved = composeAt('Google', 'Software Engineer');
    expect(saved, 'Software Engineer at Google');
    final parts = parseAt(saved);
    expect(parts.primary, 'Google');
    expect(parts.secondary, 'Software Engineer');
    expect(parseAt('Google').primary, 'Google');
  });
}


