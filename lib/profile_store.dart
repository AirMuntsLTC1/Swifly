import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'database_service.dart';
import 'native_bridge.dart';

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

class ProfileFieldDef {
  final String key;
  final String label;
  final IconData icon;
  final FieldKind kind;
  final List<String> choices;

  ProfileFieldDef(
    this.key,
    this.label,
    this.icon, {
    this.kind = FieldKind.text,
    this.choices = const <String>[],
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
    ProfileFieldDef('city', 'Current city or town', LucideIcons.mapPin),
    ProfileFieldDef('hometown', 'Hometown', LucideIcons.house),
    ProfileFieldDef('birthday', 'Birthday', LucideIcons.cake, kind: FieldKind.date),
    ProfileFieldDef('gender', 'Gender', LucideIcons.user,
        kind: FieldKind.choice, choices: ['Male', 'Female', 'Custom']),
    ProfileFieldDef('relationship', 'Relationship status', LucideIcons.heart,
        kind: FieldKind.choice,
        choices: ['Single', 'In a relationship', 'Married', 'Prefer not to say']),
    ProfileFieldDef('family', 'Family', LucideIcons.users),
    ProfileFieldDef('languages', 'Languages', LucideIcons.languages),
  ]),
  ProfileSection('Work', [
    ProfileFieldDef('work', 'Work experience', LucideIcons.briefcase),
  ]),
  ProfileSection('Education', [
    ProfileFieldDef('school', 'High school or college', LucideIcons.graduationCap),
  ]),
  ProfileSection('Hobbies', [
    ProfileFieldDef('hobbies', 'Hobbies', LucideIcons.smile),
  ]),
  ProfileSection('Interests', [
    ProfileFieldDef('music', 'Music', LucideIcons.music),
    ProfileFieldDef('tv', 'TV shows', LucideIcons.tv),
    ProfileFieldDef('movies', 'Movies', LucideIcons.video),
    ProfileFieldDef('games', 'Games', LucideIcons.gamepad2),
    ProfileFieldDef('sports', 'Sports teams and athletes', LucideIcons.shirt),
  ]),
  ProfileSection('Travel', [
    ProfileFieldDef('places', 'Places', LucideIcons.mapPin),
  ]),
  ProfileSection('Links', [
    ProfileFieldDef('website', 'Websites, blogs, portfolios', LucideIcons.link),
  ]),
  ProfileSection('Contact info', [
    ProfileFieldDef('socialMedia', 'Social media', LucideIcons.atSign),
    ProfileFieldDef('email', 'Email', LucideIcons.mail),
    ProfileFieldDef('phone', 'Phone number', LucideIcons.phone),
  ]),
];

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
