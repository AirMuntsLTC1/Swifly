import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'inbox_store.dart';

const Color _brandBlue = Color(0xFF1D6FDC);

const List<int> _colors = [
  0xFF1D6FDC, 0xFF000000, 0xFF8E24AA, 0xFFD93025, 0xFFE8710A, 0xFF0F9D58, 0xFF00897B,
];

/// Make a real story: type something, pick a colour, or add a photo.
class AddStoryScreen extends StatefulWidget {
  const AddStoryScreen({super.key});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  final TextEditingController _text = TextEditingController();
  int _color = _colors.first;
  String? _image;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

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
    if (file != null && mounted) setState(() => _image = file.path);
  }

  void _share() {
    final caption = _text.text.trim();
    if (caption.isEmpty && _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something or add a photo first')),
      );
      return;
    }
    StoryStore.instance.post(caption: caption, imagePath: _image, bgColor: _color);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Color(_color),
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_image != null)
                    Image.file(File(_image!), fit: BoxFit.contain),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: _text,
                        autofocus: true,
                        maxLines: null,
                        maxLength: 150,
                        textAlign: TextAlign.center,
                        cursorColor: Colors.white,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                        decoration: const InputDecoration(
                          hintText: 'Type your story',
                          hintStyle: TextStyle(color: Colors.white60),
                          border: InputBorder.none,
                          counterStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ],
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
                  if (_image != null)
                    IconButton(
                      tooltip: 'Remove photo',
                      onPressed: () => setState(() => _image = null),
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
                              onTap: () => setState(() => _color = c),
                              child: Container(
                                width: 30,
                                height: 30,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: _color == c ? 3 : 1.2,
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
