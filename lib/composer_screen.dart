import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'post_model.dart';
import 'tag_friends_screen.dart';
import 'upload_manager.dart';

Route<void> composerRoute() {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const ComposerScreen(),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          child: child,
          builder: (context, child) {
            final t = curved.value;
            return Transform.scale(
              scale: 0.9 + 0.1 * t,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28 * (1 - t)),
                child: child,
              ),
            );
          },
        ),
      );
    },
  );
}

class ComposerScreen extends StatefulWidget {
  const ComposerScreen({super.key});

  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _audience = 'Everyone';
  List<String> _tagged = [];
  List<File> _selectedMedia = [];
  bool _showEmojiPicker = false;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _publish() {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedMedia.isEmpty) return;
    
    final mediaPaths = _selectedMedia.map((f) => f.path).toList();
    
    UploadManager.instance.start(
      mediaPaths.isNotEmpty ? mediaPaths.first : null,
    );
    
    PostStore.instance.addPost(
      text: text,
      audience: _audience,
      taggedHandles: _tagged,
      mediaPaths: mediaPaths,
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      UploadManager.instance.success();
    });

    Navigator.pop(context);
  }

  Future<void> _openMediaPicker() async {
    if (_selectedMedia.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only select up to 10 items')),
      );
      return;
    }

    // Request Permission First
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to access photos/videos')),
        );
      }
      return;
    }

    // Open Fullscreen Custom Picker directly
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 10 - _selectedMedia.length,
        requestType: RequestType.common, // Supports both photos and videos
        themeColor: const Color(0xFF1D6FDC), // Your app's blue color
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isPicking = true);
      for (var asset in result) {
        final file = await asset.file;
        if (file != null) {
          setState(() {
            _selectedMedia.add(file);
          });
        }
      }
      setState(() => _isPicking = false);
    }
  }

  void _toggleEmoji() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _pickAudience() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final options = [
          (LucideIcons.globe, 'Everyone'),
          (LucideIcons.users, 'Followers'),
          (LucideIcons.lock, 'Only me'),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final o in options)
                  ListTile(
                    leading: Icon(o.$1, color: Colors.black),
                    title: Text(o.$2,
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.w600)),
                    trailing: _audience == o.$2
                        ? const Icon(LucideIcons.check, color: Colors.black)
                        : null,
                    onTap: () {
                      setState(() => _audience = o.$2);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTagPeople() async {
    final result =
        await Navigator.of(context).push<List<String>>(tagFriendsRoute(_tagged));
    if (result != null) {
      setState(() => _tagged = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagLabel = _tagged.isEmpty ? 'Tag people' : '${_tagged.length} tagged';
    final canPost = _textController.text.trim().isNotEmpty || _selectedMedia.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, color: Colors.black),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: canPost ? _publish : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD9D9D9),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Post',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAEAEA)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.black,
                    child: Icon(LucideIcons.user, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(kMeName,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.black)),
                        const SizedBox(height: 2),
                        const Text(kMeHandle,
                            style: TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Chip(
                              icon: LucideIcons.globe,
                              label: _audience,
                              trailing: LucideIcons.chevronDown,
                              onTap: _pickAudience,
                            ),
                            _Chip(
                              icon: LucideIcons.userPlus,
                              label: tagLabel,
                              onTap: _pickTagPeople,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedMedia.isNotEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.only(top: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _selectedMedia.length,
                  itemBuilder: (context, i) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFFF2F2F2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedMedia[i],
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedMedia.removeAt(i));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.x,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  onTap: () {
                    if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                  },
                  autofocus: _selectedMedia.isEmpty,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  cursorColor: Colors.black,
                  style: const TextStyle(fontSize: 18, height: 1.4, color: Colors.black),
                  decoration: const InputDecoration(
                    hintText: "What's happening?",
                    hintStyle: TextStyle(color: Color(0xFF8E8E8E)),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAEAEA)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Media',
                    onPressed: _isPicking ? null : _openMediaPicker,
                    icon: _isPicking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.image, color: Colors.black),
                  ),
                  IconButton(
                    tooltip: 'Emoji',
                    onPressed: _toggleEmoji,
                    icon: Icon(_showEmojiPicker ? LucideIcons.keyboard : LucideIcons.smile, color: Colors.black),
                  ),
                  const Spacer(),
                  if (_selectedMedia.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${_selectedMedia.length}/10',
                        style: const TextStyle(
                          color: Color(0xFF8E8E8E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_showEmojiPicker)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    _textController.text += emoji.emoji;
                  },
                  config: const Config(
                    height: 256,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      columns: 8,
                      emojiSizeMax: 32,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? trailing;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.black),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 15, color: Colors.black),
            ],
          ],
        ),
      ),
    );
  }
}
