import 'package:flutter/foundation.dart';

class Person {
  final String name;
  final String handle;
  final String avatarUrl;
  const Person(this.name, this.handle, {this.avatarUrl = ''});
}

/// The signed-in user. Filled after login (see app_bootstrap.dart).
/// Screens read [kMeName] and [kMeHandle], which point here.
class CurrentUser {
  static String name = 'Your Name';
  static String handle = '@yourhandle';
}

String get kMeName => CurrentUser.name;
String get kMeHandle => CurrentUser.handle;

/// Everyone the app knows about: names, follower counts, trending tags.
/// It starts EMPTY. The database (or the mock loader) fills it.
class PeopleDirectory extends ChangeNotifier {
  PeopleDirectory._();
  static final PeopleDirectory instance = PeopleDirectory._();

  List<Person> _people = const [];
  Map<String, (int, int)> _stats = const {};
  List<String> _trending = const [];

  List<Person> get people => _people;

  /// handle -> (followers, following)
  Map<String, (int, int)> get stats => _stats;
  List<String> get trending => _trending;

  void load({
    List<Person> people = const [],
    Map<String, (int, int)> stats = const {},
    List<String> trending = const [],
  }) {
    _people = List.unmodifiable(people);
    _stats = Map.unmodifiable(stats);
    _trending = List.unmodifiable(trending);
    notifyListeners();
  }
}

List<Person> get kPeople => PeopleDirectory.instance.people;
Map<String, (int, int)> get kPeopleStats => PeopleDirectory.instance.stats;
List<String> get kTrendingTags => PeopleDirectory.instance.trending;

