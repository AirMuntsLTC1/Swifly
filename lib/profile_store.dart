import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'database_service.dart';
import 'native_bridge.dart';
import 'suggest_engine.dart';

/// Who can see a profile field. The order matches the C++ privacy rule (0, 1, 2).
enum Audience { onlyMe, followers, everyone }

extension AudienceInfo on Audience {
  String get label => switch (this) {
        Audience.onlyMe => 'Only me',
        Audience.followers => 'Followers',
        Audience.everyone => 'Everyone',
      };

  IconData get icon => switch (this) {
        Audience.onlyMe => LucideIcons.lock,
        Audience.followers => LucideIcons.users,
        Audience.everyone => LucideIcons.globe,
      };
}

class ProfileField {
  String value;
  Audience audience;
  ProfileField({this.value = '', this.audience = Audience.everyone});
}

enum FieldKind { text, multiline, date, choice }

/// Extra checks for text fields that must look a certain way.
enum FieldValidator { none, email, phone, url, handle }

class ProfileFieldDef {
  final String key;
  final String label;
  final IconData icon;
  final FieldKind kind;
  final List<String> choices;

  /// If set, the editor searches this list as the person types.
  final SuggestKind? suggest;

  /// Optional second search box (job title for work, field of study for school).
  /// The two are saved together as "Secondary at Primary".
  final SuggestKind? secondary;

  /// True if the field holds several picks (hobbies, music ...), shown as chips.
  final bool multi;

  final FieldValidator validator;

  ProfileFieldDef(
    this.key,
    this.label,
    this.icon, {
    this.kind = FieldKind.text,
    this.choices = const <String>[],
    this.suggest,
    this.secondary,
    this.multi = false,
    this.validator = FieldValidator.none,
  });
}

class ProfileSection {
  final String title;
  final List<ProfileFieldDef> fields;
  ProfileSection(this.title, this.fields);
}

/// Every editable profile field, grouped into sections. Both the Edit profile
/// screen and the profile tab are built from this list. To add a field, add it here.
final List<ProfileSection> kProfileSections = [
  ProfileSection('Intro', [
    ProfileFieldDef('bio', 'Bio', LucideIcons.messageCircle, kind: FieldKind.multiline),
  ]),
  ProfileSection('Personal details', [
    ProfileFieldDef('city', 'Current city or town', LucideIcons.mapPin, suggest: SuggestKind.place),
    ProfileFieldDef('hometown', 'Hometown', LucideIcons.house, suggest: SuggestKind.place),
    ProfileFieldDef('birthday', 'Birthday', LucideIcons.cake, kind: FieldKind.date),
    ProfileFieldDef('gender', 'Gender', LucideIcons.user,
        kind: FieldKind.choice, choices: ['Male', 'Female', 'Custom']),
    ProfileFieldDef('relationship', 'Relationship status', LucideIcons.heart,
        kind: FieldKind.choice,
        choices: ['Single', 'In a relationship', 'Married', 'Prefer not to say']),
    ProfileFieldDef('family', 'Family', LucideIcons.users),
    ProfileFieldDef('languages', 'Languages', LucideIcons.languages,
        suggest: SuggestKind.language, multi: true),
  ]),
  ProfileSection('Work', [
    ProfileFieldDef('work', 'Work experience', LucideIcons.briefcase,
        suggest: SuggestKind.company, secondary: SuggestKind.jobTitle),
  ]),
  ProfileSection('Education', [
    ProfileFieldDef('school', 'High school or college', LucideIcons.graduationCap,
        suggest: SuggestKind.school, secondary: SuggestKind.fieldOfStudy),
  ]),
  ProfileSection('Hobbies', [
    ProfileFieldDef('hobbies', 'Hobbies', LucideIcons.smile,
        suggest: SuggestKind.hobby, multi: true),
  ]),
  ProfileSection('Interests', [
    ProfileFieldDef('music', 'Music', LucideIcons.music, suggest: SuggestKind.music, multi: true),
    ProfileFieldDef('tv', 'TV shows', LucideIcons.tv, suggest: SuggestKind.tv, multi: true),
    ProfileFieldDef('movies', 'Movies', LucideIcons.video, suggest: SuggestKind.movie, multi: true),
    ProfileFieldDef('games', 'Games', LucideIcons.gamepad2, suggest: SuggestKind.game, multi: true),
    ProfileFieldDef('sports', 'Sports teams and athletes', LucideIcons.shirt,
        suggest: SuggestKind.sport, multi: true),
  ]),
  ProfileSection('Travel', [
    ProfileFieldDef('places', 'Places', LucideIcons.mapPin, suggest: SuggestKind.place, multi: true),
  ]),
  ProfileSection('Links', [
    ProfileFieldDef('website', 'Websites, blogs, portfolios', LucideIcons.link,
        validator: FieldValidator.url),
  ]),
  ProfileSection('Contact info', [
    ProfileFieldDef('socialMedia', 'Social media', LucideIcons.atSign,
        validator: FieldValidator.handle),
    ProfileFieldDef('email', 'Email', LucideIcons.mail, validator: FieldValidator.email),
    ProfileFieldDef('phone', 'Phone number', LucideIcons.phone, validator: FieldValidator.phone),
  ]),
];

final RegExp _emailRe = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');
final RegExp _urlRe = RegExp(
    r'^(https?://)?([A-Za-z0-9\-]+\.)+[A-Za-z]{2,}(:\d+)?(/\S*)?$',
    caseSensitive: false);
final RegExp _handleRe = RegExp(r'^[A-Za-z0-9._]{1,30}$');

/// Tidies a typed value before it is checked and saved.
String normalizeFieldText(ProfileFieldDef d, String raw) {
  final v = raw.trim();
  switch (d.validator) {
    case FieldValidator.email:
      return v.toLowerCase();
    case FieldValidator.handle:
      return v.startsWith('@') ? v.substring(1).trim() : v;
    case FieldValidator.phone:
      return v.replaceAll(RegExp(r'\s+'), ' ');
    case FieldValidator.url:
    case FieldValidator.none:
      return v;
  }
}

/// Returns a short message if [value] is not acceptable, or null if it is fine.
/// An empty value is always fine (it clears the field).
String? validateFieldText(ProfileFieldDef d, String value) {
  if (value.isEmpty) return null;
  switch (d.validator) {
    case FieldValidator.email:
      return _emailRe.hasMatch(value) ? null : 'Enter a valid email, like name@example.com';
    case FieldValidator.phone:
      final digits = value.replaceAll(RegExp(r'\D'), '');
      final okChars = RegExp(r'^[0-9+\-() ]+$').hasMatch(value);
      return okChars && digits.length >= 7 && digits.length <= 15
          ? null
          : 'Enter a valid phone number, like +234 801 234 5678';
    case FieldValidator.url:
      return _urlRe.hasMatch(value) ? null : 'Enter a valid link, like example.com';
    case FieldValidator.handle:
      return _handleRe.hasMatch(value)
          ? null
          : 'Use letters, numbers, dots and underscores only (max 30)';
    case FieldValidator.none:
      return null;
  }
}

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// yyyy-mm-dd, the format the birthday is stored in.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The value as people read it: "March 28, 2005" for dates, the text otherwise.
String displayValue(ProfileFieldDef d, ProfileField f) {
  if (d.kind == FieldKind.date) {
    final date = DateTime.tryParse(f.value);
    if (date == null) return f.value;
    return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }
  return f.value;
}

/// The signed-in user's profile. The only place profile data lives.
/// Saving calls DatabaseService; the screens listen to this store.
class ProfileStore extends ChangeNotifier {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  String? avatarPath;
  final Map<String, ProfileField> _fields = {};

  ProfileField fieldFor(String key) => _fields.putIfAbsent(key, () => ProfileField());

  /// Replaces all values. Called with mock data now, database results later.
  void load(Map<String, ProfileField> saved, {String? avatar}) {
    _fields
      ..clear()
      ..addAll(saved);
    avatarPath = avatar;
    notifyListeners();
  }

  /// Fills the store from the database. Call once after sign-in.
  /// Unknown keys are ignored and unknown audiences fall back to Everyone,
  /// so adding a field later never breaks older saved data.
  Future<void> loadFromDatabase() async {
    try {
      final rows = await DatabaseService.instance.fetchProfileFields();
      if (rows.isEmpty) return;
      final known = {for (final s in kProfileSections) for (final d in s.fields) d.key};
      final saved = <String, ProfileField>{};
      for (final r in rows) {
        final key = r['key'] ?? '';
        if (!known.contains(key)) continue;
        final audience = Audience.values.firstWhere(
          (a) => a.name == r['audience'],
          orElse: () => Audience.everyone,
        );
        saved[key] = ProfileField(value: (r['value'] ?? '').trim(), audience: audience);
      }
      load(saved, avatar: avatarPath);
    } catch (_) {}
  }

  void setValue(String key, String value) {
    fieldFor(key).value = value.trim();
    notifyListeners();
    _save(key);
  }

  void setAudience(String key, Audience audience) {
    fieldFor(key).audience = audience;
    notifyListeners();
    _save(key);
  }

  Future<void> setAvatar(String path) async {
    avatarPath = path;
    notifyListeners();
    try {
      await DatabaseService.instance.uploadAvatar(path);
    } catch (_) {}
  }

  void _save(String key) {
    final f = fieldFor(key);
    DatabaseService.instance
        .saveProfileField(key, f.value, f.audience.name)
        .catchError((_) {});
  }

  /// Age from the birthday, calculated by the C++ core. Null if no valid birthday is set.
  int? get ageYears {
    final d = DateTime.tryParse(fieldFor('birthday').value);
    if (d == null) return null;
    final now = DateTime.now();
    final age = NativeCore.ageYears(d.year, d.month, d.day, now.year, now.month, now.day);
    return age < 0 ? null : age;
  }

  /// Privacy check from the C++ core. Use this when another person views a field.
  bool canSee(String key, {required bool viewerFollowsOwner}) => NativeCore.canSee(
        fieldFor(key).audience.index,
        isOwner: false,
        viewerFollowsOwner: viewerFollowsOwner,
      );
}
