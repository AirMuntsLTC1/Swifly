/// Everything a story is made of. The editor, the viewer and the chat thumbnail
/// all draw the same [StoryData], so what you build is exactly what people see.
///
/// Positions are saved as fractions of the story (0..1) so a story looks the
/// same on every phone size.

/// Logical size every story is laid out in, then scaled to fit the screen.
const double kStoryW = 360;
const double kStoryH = 640;

enum StoryLayerKind { text, sticker, place }

class StoryLayer {
  final String id;
  final StoryLayerKind kind;

  /// Text kind: the words. Sticker kind: the sticker id. Place kind: the label.
  String text;

  /// Text colour (ARGB int). Only used by text layers.
  int color;

  /// Text drawn on a coloured box instead of plain.
  bool boxed;

  /// Centre of the layer as a fraction of the story width / height.
  double dx;
  double dy;
  double scale;
  double rotation;

  StoryLayer({
    required this.id,
    required this.kind,
    required this.text,
    this.color = 0xFFFFFFFF,
    this.boxed = false,
    this.dx = 0.5,
    this.dy = 0.5,
    this.scale = 1,
    this.rotation = 0,
  });

  StoryLayer copy() => StoryLayer(
        id: id,
        kind: kind,
        text: text,
        color: color,
        boxed: boxed,
        dx: dx,
        dy: dy,
        scale: scale,
        rotation: rotation,
      );
}

class StoryData {
  int bgColor;
  String? photoPath;
  double photoScale;
  double photoDx; // fraction of story width
  double photoDy; // fraction of story height
  double photoRotation;
  final List<StoryLayer> layers;

  StoryData({
    this.bgColor = 0xFF1D6FDC,
    this.photoPath,
    this.photoScale = 1,
    this.photoDx = 0,
    this.photoDy = 0,
    this.photoRotation = 0,
    List<StoryLayer>? layers,
  }) : layers = layers ?? <StoryLayer>[];

  bool get hasContent => photoPath != null || layers.isNotEmpty;

  /// First text on the story (used for previews).
  String get caption {
    for (final l in layers) {
      if (l.kind == StoryLayerKind.text && l.text.trim().isNotEmpty) return l.text.trim();
    }
    return '';
  }

  /// The location label, if the story has one.
  String? get place {
    for (final l in layers) {
      if (l.kind == StoryLayerKind.place && l.text.trim().isNotEmpty) return l.text.trim();
    }
    return null;
  }

  void resetPhotoTransform() {
    photoScale = 1;
    photoDx = 0;
    photoDy = 0;
    photoRotation = 0;
  }

  StoryData copy() => StoryData(
        bgColor: bgColor,
        photoPath: photoPath,
        photoScale: photoScale,
        photoDx: photoDx,
        photoDy: photoDy,
        photoRotation: photoRotation,
        layers: [for (final l in layers) l.copy()],
      );
}

/// How an animated sticker moves.
enum StickerMotion { pulse, bounce, spin, float, wiggle, beat, twinkle }

class StickerDef {
  final String id;
  final String emoji;
  final StickerMotion motion;
  const StickerDef(this.id, this.emoji, this.motion);
}

const List<StickerDef> kStickers = [
  StickerDef('heart', '❤️', StickerMotion.beat),
  StickerDef('fire', '🔥', StickerMotion.pulse),
  StickerDef('laugh', '😂', StickerMotion.bounce),
  StickerDef('love', '😍', StickerMotion.beat),
  StickerDef('party', '🎉', StickerMotion.wiggle),
  StickerDef('sparkles', '✨', StickerMotion.twinkle),
  StickerDef('star', '⭐', StickerMotion.spin),
  StickerDef('rainbow', '🌈', StickerMotion.float),
  StickerDef('butterfly', '🦋', StickerMotion.float),
  StickerDef('flower', '🌸', StickerMotion.spin),
  StickerDef('sun', '☀️', StickerMotion.spin),
  StickerDef('moon', '🌙', StickerMotion.float),
  StickerDef('dizzy', '💫', StickerMotion.spin),
  StickerDef('clap', '👏', StickerMotion.wiggle),
  StickerDef('cool', '😎', StickerMotion.bounce),
  StickerDef('partyface', '🥳', StickerMotion.wiggle),
  StickerDef('sparkleheart', '💖', StickerMotion.beat),
  StickerDef('pizza', '🍕', StickerMotion.wiggle),
  StickerDef('music', '🎶', StickerMotion.float),
  StickerDef('rocket', '🚀', StickerMotion.bounce),
  StickerDef('camera', '📸', StickerMotion.pulse),
  StickerDef('palm', '🌴', StickerMotion.wiggle),
  StickerDef('wave', '👋', StickerMotion.wiggle),
  StickerDef('hundred', '💯', StickerMotion.pulse),
  StickerDef('crown', '👑', StickerMotion.bounce),
  StickerDef('ghost', '👻', StickerMotion.float),
  StickerDef('cake', '🎂', StickerMotion.pulse),
  StickerDef('gift', '🎁', StickerMotion.bounce),
  StickerDef('balloon', '🎈', StickerMotion.float),
  StickerDef('cry', '😭', StickerMotion.bounce),
  StickerDef('thumbs', '👍', StickerMotion.pulse),
  StickerDef('coffee', '☕', StickerMotion.float),
];

StickerDef? stickerById(String id) {
  for (final s in kStickers) {
    if (s.id == id) return s;
  }
  return null;
}



