import 'database_service.dart';
import 'app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'inbox_store.dart';
import 'story_location_sheet.dart';
import 'story_models.dart';
import 'story_widgets.dart';

const Color _brandBlue = Color(0xFF1D6FDC);

const List<int> _colors = [
  0xFF1D6FDC, 0xFF000000, 0xFF8E24AA, 0xFFD93025, 0xFFE8710A, 0xFF0F9D58, 0xFF00897B,
];

const List<int> _textColors = [
  0xFFFFFFFF, 0xFF000000, 0xFFFFD60A, 0xFFFF453A, 0xFFFF9F0A, 0xFF30D158, 0xFF0A84FF, 0xFFFF2D92,
];

/// Make a real story: photo you can pinch / drag, text you can move and resize,
/// animated stickers and a location tag for where you live.
class AddStoryScreen extends StatefulWidget {
  const AddStoryScreen({super.key});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  final StoryData _data = StoryData(bgColor: _colors.first);
  final Map<String, GlobalKey> _keys = {};
  final GlobalKey _canvasKey = GlobalKey();
  int _seq = 0;
  String? _hiddenId;

  // Gesture state (one gesture moves one thing: a layer, or the photo).
  StoryLayer? _gLayer;
  bool _gPhoto = false;
  double _s0 = 1, _r0 = 0, _dx0 = 0, _dy0 = 0;
  Offset _f0 = Offset.zero;
  bool _dragging = false;
  bool _overTrash = false;

  // ---------- helpers ----------

  String _newId() => 'l${++_seq}';

  void _addLayer(StoryLayer l) {
    _keys[l.id] = GlobalKey();
    _data.layers.add(l);
  }

  void _removeLayer(StoryLayer l) {
    _data.layers.remove(l);
    _keys.remove(l.id);
  }

  RenderBox? _canvasBox() {
    final ro = _canvasKey.currentContext?.findRenderObject();
    return ro is RenderBox && ro.attached ? ro : null;
  }

  Rect? _trashRect() {
    final box = _canvasBox();
    if (box == null) return null;
    final tl = box.localToGlobal(Offset.zero);
    final c = Offset(tl.dx + box.size.width / 2, tl.dy + box.size.height - 52);
    return Rect.fromCenter(center: c, width: 110, height: 110);
  }

  StoryLayer? _hitLayer(Offset global) {
    for (final l in _data.layers.reversed) {
      final ctx = _keys[l.id]?.currentContext;
      final ro = ctx?.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      final local = ro.globalToLocal(global);
      if ((Offset.zero & ro.size).inflate(16).contains(local)) return l;
    }
    return null;
  }

  // ---------- gestures ----------

  void _onScaleStart(ScaleStartDetails d) {
    _f0 = d.focalPoint;
    final hit = _hitLayer(d.focalPoint);
    if (hit != null) {
      _gLayer = hit;
      _gPhoto = false;
      _s0 = hit.scale;
      _r0 = hit.rotation;
      _dx0 = hit.dx;
      _dy0 = hit.dy;
      // Bring the touched layer to the front.
      _data.layers.remove(hit);
      _data.layers.add(hit);
      setState(() => _dragging = true);
    } else if (_data.photoPath != null) {
      _gLayer = null;
      _gPhoto = true;
      _s0 = _data.photoScale;
      _r0 = _data.photoRotation;
      _dx0 = _data.photoDx;
      _dy0 = _data.photoDy;
    } else {
      _gLayer = null;
      _gPhoto = false;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final box = _canvasBox();
    if (box == null) return;
    final size = box.size;
    final delta = d.focalPoint - _f0;
    final l = _gLayer;
    if (l != null) {
      setState(() {
        l.dx = _dx0 + delta.dx / size.width;
        l.dy = _dy0 + delta.dy / size.height;
        l.scale = (_s0 * d.scale).clamp(0.3, 6.0).toDouble();
        l.rotation = _r0 + d.rotation;
        _overTrash = _trashRect()?.contains(d.focalPoint) ?? false;
      });
    } else if (_gPhoto) {
      setState(() {
        _data.photoDx = _dx0 + delta.dx / size.width;
        _data.photoDy = _dy0 + delta.dy / size.height;
        _data.photoScale = (_s0 * d.scale).clamp(0.4, 8.0).toDouble();
        _data.photoRotation = _r0 + d.rotation;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final l = _gLayer;
    setState(() {
      if (l != null && _overTrash) _removeLayer(l);
      _dragging = false;
      _overTrash = false;
      _gLayer = null;
      _gPhoto = false;
    });
  }

  Future<void> _onTapUp(TapUpDetails d) async {
    final hit = _hitLayer(d.globalPosition);
    if (hit != null) {
      if (hit.kind == StoryLayerKind.text) {
        await _editText(hit);
      } else if (hit.kind == StoryLayerKind.place) {
        await _addPlace();
      }
      return;
    }
    if (!_data.layers.any((l) => l.kind == StoryLayerKind.text)) {
      await _editText(null);
    }
  }

  // ---------- text ----------

  /// Adds a new text, or edits [existing].
  Future<void> _editText(StoryLayer? existing) async {
    if (existing != null) setState(() => _hiddenId = existing.id);
    final result = await Navigator.of(context).push<_TextResult>(
      PageRouteBuilder<_TextResult>(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => _TextEditPage(
          text: existing?.text ?? '',
          color: existing?.color ?? 0xFFFFFFFF,
          boxed: existing?.boxed ?? false,
        ),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
    if (!mounted) return;
    setState(() {
      _hiddenId = null;
      if (result == null) return;
      final text = result.text.trim();
      if (existing != null) {
        if (text.isEmpty) {
          _removeLayer(existing);
        } else {
          existing.text = text;
          existing.color = result.color;
          existing.boxed = result.boxed;
        }
      } else if (text.isNotEmpty) {
        _addLayer(StoryLayer(
          id: _newId(),
          kind: StoryLayerKind.text,
          text: text,
          color: result.color,
          boxed: result.boxed,
          dx: 0.5,
          dy: 0.45,
        ));
      }
    });
  }

  // ---------- stickers ----------

  Future<void> _addSticker() async {
    final def = await showModalBottomSheet<StickerDef>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _StickerSheet(),
    );
    if (def == null || !mounted) return;
    setState(() {
      _addLayer(StoryLayer(
        id: _newId(),
        kind: StoryLayerKind.sticker,
        text: def.id,
        dx: 0.5,
        dy: 0.35,
        scale: 1.4,
      ));
    });
  }

  // ---------- location ----------

  Future<void> _addPlace() async {
    final label = await showStoryLocationSheet(context);
    if (label == null || label.isEmpty || !mounted) return;
    setState(() {
      StoryLayer? old;
      for (final l in _data.layers) {
        if (l.kind == StoryLayerKind.place) old = l;
      }
      if (old != null) {
        old.text = label;
      } else {
        _addLayer(StoryLayer(
          id: _newId(),
          kind: StoryLayerKind.place,
          text: label,
          dx: 0.5,
          dy: 0.8,
        ));
      }
    });
  }

  // ---------- photo ----------

  Future<void> _pickPhoto() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allow photo access to add a photo')),
        );
      }
      return;
    }
    if (!mounted) return;
    final result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.image,
        themeColor: _brandBlue,
      ),
    );
    if (result == null || result.isEmpty) return;
    final file = await result.first.file;
    if (file != null && mounted) {
      setState(() {
        _data.photoPath = file.path;
        _data.resetPhotoTransform();
      });
    }
  }

  // ---------- share ----------

  void _share() {
    if (!_data.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add text, a photo or a sticker first')),
      );
      return;
    }
    final data = _data.copy();
    StoryStore.instance.post(data);
    Navigator.pop(context, true);
    // Saved to Supabase in the background; the id is kept so it can be deleted or answered.
    DatabaseService.instance
        .publishStory(data)
        .then((id) => StoryStore.instance.setStoryId(id))
        .catchError((Object e) => reportError('Story not shared', e));
  }

  // ---------- UI ----------

  Widget _toolButton({required Widget child, required String tip, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tooltip(
        message: tip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0x73000000), shape: BoxShape.circle),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Color(_data.bgColor),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add story',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _share,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: const Text('Share',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: kStoryW / kStoryH,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          onScaleEnd: _onScaleEnd,
                          onTapUp: _onTapUp,
                          child: StoryCanvas(
                            key: _canvasKey,
                            data: _data,
                            showHint: true,
                            layerKeys: _keys,
                            hiddenLayerId: _hiddenId,
                          ),
                        ),
                      ),
                      // Tools on the right.
                      Positioned(
                        top: 10,
                        right: 8,
                        child: Column(
                          children: [
                            _toolButton(
                              tip: 'Add text',
                              onTap: () => _editText(null),
                              child: const Text('Aa',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16)),
                            ),
                            _toolButton(
                              tip: 'Add sticker',
                              onTap: _addSticker,
                              child: const Icon(LucideIcons.smile, color: Colors.white, size: 22),
                            ),
                            _toolButton(
                              tip: 'Add location',
                              onTap: _addPlace,
                              child: const Icon(LucideIcons.mapPin, color: Colors.white, size: 22),
                            ),
                          ],
                        ),
                      ),
                      // Drag a sticker, text or location here to delete it.
                      if (_dragging)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 24,
                          child: IgnorePointer(
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: _overTrash ? 66 : 56,
                                height: _overTrash ? 66 : 56,
                                decoration: BoxDecoration(
                                  color: _overTrash
                                      ? const Color(0xFFD93025)
                                      : const Color(0x99000000),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.trash2, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Add photo',
                    onPressed: _pickPhoto,
                    icon: const Icon(LucideIcons.image, color: Colors.white),
                  ),
                  if (_data.photoPath != null)
                    IconButton(
                      tooltip: 'Remove photo',
                      onPressed: () => setState(() {
                        _data.photoPath = null;
                        _data.resetPhotoTransform();
                      }),
                      icon: const Icon(LucideIcons.trash2, color: Colors.white),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final c in _colors)
                            GestureDetector(
                              onTap: () => setState(() => _data.bgColor = c),
                              child: Container(
                                width: 30,
                                height: 30,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: _data.bgColor == c ? 3 : 1.2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text editor overlay
// ---------------------------------------------------------------------------

class _TextResult {
  final String text;
  final int color;
  final bool boxed;
  const _TextResult(this.text, this.color, this.boxed);
}

class _TextEditPage extends StatefulWidget {
  final String text;
  final int color;
  final bool boxed;
  const _TextEditPage({required this.text, required this.color, required this.boxed});

  @override
  State<_TextEditPage> createState() => _TextEditPageState();
}

class _TextEditPageState extends State<_TextEditPage> {
  late final TextEditingController _c = TextEditingController(text: widget.text);
  late int _color = widget.color;
  late bool _boxed = widget.boxed;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, _TextResult(_c.text, _color, _boxed));

  @override
  Widget build(BuildContext context) {
    final col = Color(_color);
    final fg = _boxed ? (col.computeLuminance() > 0.6 ? Colors.black : Colors.white) : col;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _boxed = !_boxed),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _boxed ? Colors.white : Colors.transparent,
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('A',
                          style: TextStyle(
                              color: _boxed ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _done,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Text('Done',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: _boxed
                        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                        : EdgeInsets.zero,
                    decoration: _boxed
                        ? BoxDecoration(color: col, borderRadius: BorderRadius.circular(12))
                        : null,
                    child: TextField(
                        controller: _c,
                        autofocus: true,
                        maxLines: null,
                        maxLength: 150,
                        textAlign: TextAlign.center,
                        cursorColor: fg,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: fg, fontSize: 28, fontWeight: FontWeight.w800),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Type your story',
                          hintStyle: TextStyle(color: fg.withAlpha(128)),
                          border: InputBorder.none,
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                  ),
                ),
              ),
            ),
            Text('${_c.text.characters.length}/150',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in _textColors)
                      GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: _color == c ? 3.5 : 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticker sheet
// ---------------------------------------------------------------------------

class _StickerSheet extends StatelessWidget {
  const _StickerSheet();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD0D0D0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Stickers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: kStickers.length,
              itemBuilder: (context, i) {
                final s = kStickers[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pop(context, s),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AnimatedSticker(emoji: s.emoji, motion: s.motion, size: 38),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



