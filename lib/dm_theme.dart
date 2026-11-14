import 'dart:io';

import 'package:flutter/material.dart';

import 'avatar_cache.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'post_model.dart';
import 'profile_store.dart';
import 'people_directory.dart';

/// Colors for the Messages screens (inbox, chat, notes, filters).
/// Dark is the default (like the Instagram screenshots); switch in the inbox menu.
class DmColors {
  final bool dark;
  const DmColors(this.dark);

  Color get bg => dark ? const Color(0xFF0A0D12) : Colors.white;
  Color get sheet => dark ? const Color(0xFF1A1D21) : const Color(0xFFF7F7F7);
  Color get text => dark ? Colors.white : Colors.black;
  Color get sub => dark ? const Color(0xFFA8ADB4) : const Color(0xFF737373);
  Color get chipBorder => dark ? const Color(0xFF3A3F47) : const Color(0xFFDBDBDB);
  Color get chipFill => dark ? const Color(0xFF262A30) : const Color(0xFFEFEFEF);
  Color get field => dark ? const Color(0xFF1C2025) : const Color(0xFFEFEFEF);
  Color get bubbleThem => dark ? const Color(0xFF262A30) : const Color(0xFFEFEFEF);
  Color get quoteBubble => dark ? const Color(0xFF1B1F24) : const Color(0xFFE4E4E4);
  Color get divider => dark ? const Color(0xFF20252B) : const Color(0xFFEAEAEA);
  Color get blue => const Color(0xFF3E7BFA);
  /// Unread badges and dots.
  Color get badge => const Color(0xFFFF3B30);
  Color get noteBubble => dark ? const Color(0xFF22262B) : const Color(0xFFF0F0F0);
  Color get noteText => dark ? const Color(0xFFB8BCC2) : const Color(0xFF555555);
}

/// Holds the dark/light choice for the Messages screens.
class DmTheme extends ChangeNotifier {
  DmTheme._();
  static final DmTheme instance = DmTheme._();

  // White theme by default, like the rest of the app.
  bool _dark = false;
  bool get dark => _dark;
  DmColors get c => DmColors(_dark);

  void toggle() {
    _dark = !_dark;
    notifyListeners();
  }
}

/// Scale for sizes so the Messages screens fit small and large phones.
double dmScale(BuildContext context) =>
    (MediaQuery.of(context).size.width / 390).clamp(0.82, 1.12).toDouble();

const LinearGradient kStoryRing = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [Color(0xFFFFC107), Color(0xFFFF3D77), Color(0xFFC13DD6)],
);

const LinearGradient kBubbleMe = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF7A4DFF), Color(0xFF3F7BFF)],
);

Color _tint(String handle) {
  var h = 7;
  for (final r in handle.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  const palette = [
    Color(0xFF8E24AA), Color(0xFF00897B), Color(0xFFE8710A), Color(0xFF1D6FDC),
    Color(0xFFD81B60), Color(0xFF5E35B1), Color(0xFF43A047), Color(0xFFF4511E),
  ];
  return palette[h % palette.length];
}

/// Round profile picture. Shows my photo for me, a coloured initial for others.
/// [ring] draws the gradient story ring (the person has an unseen story).
class DmAvatar extends StatelessWidget {
  final String handle;
  final double size;
  final bool ring;
  final Color? gap;

  const DmAvatar({super.key, required this.handle, this.name, this.size = 56, this.ring = false, this.gap});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final c = DmTheme.instance.c;
    final isMe = handle == kMeHandle;
    String? path = isMe ? ProfileStore.instance.avatarPath : null;
    if (path == null || path.isEmpty) {
      for (final p in kPeople) {
        if (p.handle == handle && p.avatarUrl.isNotEmpty) {
          path = p.avatarUrl;
          break;
        }
      }
    }
    final displayName = this.name ?? (isMe ? kMeName : nameForHandle(handle));
    final hasImage = path != null && path.isNotEmpty;
    final inner = ring ? size - 8 : size;
    
    Widget fallback() {
      final letter = displayName.replaceAll('@', '').trim().isEmpty
          ? '?'
          : displayName.replaceAll('@', '').trim().characters.first.toUpperCase();
      return Center(
        child: Text(letter,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: inner * 0.42)),
      );
    }

    final face = Container(
      width: inner,
      height: inner,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _tint(handle),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? (path!.startsWith('http')
              // Remote picture: saved on the phone after the first download.
              ? CachedAvatarImage(url: path, size: inner, fallback: fallback())
              : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback()))
          : fallback(),
    );
    if (!ring) return face;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: kStoryRing),
      alignment: Alignment.center,
      child: Container(
        width: size - 4,
        height: size - 4,
        decoration: BoxDecoration(shape: BoxShape.circle, color: gap ?? c.bg),
        alignment: Alignment.center,
        child: face,
      ),
    );
  }
}

/// True when this person has a story I can watch.
bool hasUnseenStory(String handle) => StoryStore.instance.otherStory(handle) != null;

/// Display name for any handle (including me).
String dmName(String handle) => handle == kMeHandle ? kMeName : nameForHandle(handle);

/// Listenable that fires when anything the Messages screens show changes.
Listenable dmListenable() => Listenable.merge([
      ChatStore.instance,
      NoteStore.instance,
      FollowStore.instance,
      StoryStore.instance,
      DmTheme.instance,
    ]);
