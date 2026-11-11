import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'create_sheet.dart';
import 'discover_panel.dart';
import 'feed_widgets.dart';
import 'post_model.dart';
import 'connections_screen.dart';
import 'suggestions_screen.dart';
import 'search_history.dart';
import 'upload_manager.dart';
import 'tag_friends_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _anim = Duration(milliseconds: 320);
  static const double _pill = 44;
  static const double _navWidth = 176;

  int _index = 0;
  bool _searchOpen = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _recordQuery() {
    final q = _query.trim();
    if (q.isNotEmpty) SearchHistory.instance.add(q);
  }

  void _closeSearch() {
    _recordQuery();
    _searchFocus.unfocus();
    _searchController.clear();
    setState(() {
      _searchOpen = false;
      _query = '';
    });
  }

  void _toggleSearch() {
    if (_searchOpen) {
      _closeSearch();
    } else {
      _openSearch();
    }
  }

  void _selectTab(int i) {
    _recordQuery();
    _searchFocus.unfocus();
    _searchController.clear();
    setState(() {
      _index = i;
      _searchOpen = false;
      _query = '';
    });
  }

  void _applyQuery(String value) {
    final q = value.trim();
    _searchController.text = q;
    _searchController.selection =
        TextSelection.collapsed(offset: q.length);
    setState(() {
      _query = q;
      _searchOpen = true;
    });
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_searchOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _searchOpen) _closeSearch();
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
          children: [
            _buildTopBar(),
            const Divider(height: 1, color: Color(0xFFEAEAEA)),
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(
                    index: _index,
                    children: const [
                      FeedTab(),
                      MessagesTab(),
                      NotificationsTab(),
                      ProfileTab(),
                    ],
                  ),
                  _buildDiscoverOverlay(),
                ],
              ),
            ),
          ],
            ),
          ),
          const UploadBanner(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: () => showCreateSheet(context),
        child: const Icon(LucideIcons.plus, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  /// Discover panel: expands from the top to fill the screen when search opens.
  Widget _buildDiscoverOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_searchOpen,
        child: AnimatedOpacity(
          opacity: _searchOpen ? 1 : 0,
          duration: _anim,
          child: AnimatedScale(
            scale: _searchOpen ? 1 : 0.94,
            alignment: Alignment.topCenter,
            duration: _anim,
            curve: Curves.easeOutCubic,
            child: Container(
              color: Colors.white,
              child: DiscoverPanel(
                query: _query,
                onPickQuery: _applyQuery,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fixed-height top bar. Search expands to the right; nav icons slide out.
  Widget _buildTopBar() {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fullWidth = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedPositioned(
                  duration: _anim,
                  curve: Curves.easeInOutCubic,
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _searchOpen ? fullWidth : _pill,
                  child: _searchPill(_searchOpen ? fullWidth : _pill),
                ),
                AnimatedPositioned(
                  duration: _anim,
                  curve: Curves.easeInOutCubic,
                  top: 0,
                  bottom: 0,
                  right: _searchOpen ? -(_navWidth + 16) : 0,
                  width: _navWidth,
                  child: _navRow(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _searchPill(double width) {
    final fieldWidth = math.max(0.0, width - 2 * _pill);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Search icon (left). Tapping it opens or closes search.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _pill,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggleSearch,
              child: const Center(
                child: Icon(LucideIcons.search, size: 20, color: Colors.black),
              ),
            ),
          ),
          // Text field, visible only while open.
          Positioned(
            left: _pill,
            top: 0,
            bottom: 0,
            width: fieldWidth,
            child: AnimatedOpacity(
              opacity: _searchOpen ? 1 : 0,
              duration: _anim,
              child: IgnorePointer(
                ignoring: !_searchOpen,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  cursorColor: Colors.black,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (v) {
                    final q = v.trim();
                    if (q.isNotEmpty) SearchHistory.instance.add(q);
                  },
                  style: const TextStyle(color: Colors.black, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: Color(0xFF8E8E8E)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
          // X button (right). Shows only while search is open.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _pill,
            child: AnimatedOpacity(
              opacity: _searchOpen ? 1 : 0,
              duration: _anim,
              child: IgnorePointer(
                ignoring: !_searchOpen,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _closeSearch,
                  child: const Center(
                    child: Icon(LucideIcons.x, size: 20, color: Colors.black),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navRow() {
    const labels = ['Home', 'Messages', 'Notifications', 'Profile'];
    final icons = [
      LucideIcons.house,
      LucideIcons.messageCircle,
      LucideIcons.bell,
      LucideIcons.user,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (int i = 0; i < 4; i++)
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: labels[i],
              onPressed: () => _selectTab(i),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(icons[i], color: Colors.black, size: 22),
              style: IconButton.styleFrom(
                backgroundColor:
                    _index == i ? const Color(0xFFE6E6E6) : Colors.transparent,
                minimumSize: const Size(40, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const CircleBorder(),
              ),
            ),
          ),
      ],
    );
  }

}

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  static const List<Map<String, String>> _chats = [
    {'name': 'Ava Stone', 'msg': 'See you at the hike!', 'time': '9:12'},
    {'name': 'Liam Park', 'msg': 'Check out my new build', 'time': '8:40'},
    {'name': 'Mia Chen', 'msg': 'Coffee on Saturday?', 'time': 'Yesterday'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _chats.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEAEAEA)),
      itemBuilder: (context, i) {
        final c = _chats[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: const CircleAvatar(
            backgroundColor: Colors.black,
            child: Icon(LucideIcons.user, color: Colors.white, size: 20),
          ),
          title: Text(c['name']!,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
          subtitle: Text(c['msg']!, style: const TextStyle(color: Color(0xFF6E6E6E))),
          trailing: Text(c['time']!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
        );
      },
    );
  }
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Ava Stone liked your post', 0),
      ('Liam Park commented: "Nice work!"', 1),
      ('Mia Chen started following you', 2),
      ('Noah Reed liked your photo', 0),
    ];
    final icons = [LucideIcons.heart, LucideIcons.messageCircle, LucideIcons.userPlus];
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEAEAEA)),
      itemBuilder: (context, i) {
        final n = items[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(icons[n.$2], color: Colors.black),
          title: Text(n.$1, style: const TextStyle(color: Colors.black, fontSize: 15)),
        );
      },
    );
  }
}


class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final Set<String> _followed = {};

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 44,
            backgroundColor: Colors.black,
            child: Icon(LucideIcons.user, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 14),
          const Text(kMeName,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 4),
          const Text(kMeHandle, style: TextStyle(color: Color(0xFF8E8E8E))),
          const SizedBox(height: 10),
          const Text('Building something cool. Coffee and code.',
              style: TextStyle(color: Colors.black, height: 1.4)),
          const SizedBox(height: 20),
          Row(
            children: [
              const _Stat(label: 'Posts', value: '24'),
              const SizedBox(width: 32),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionsScreen(initialFollowers: true))),
                child: const _Stat(label: 'Followers', value: '1.2K'),
              ),
              const SizedBox(width: 32),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionsScreen(initialFollowers: false))),
                child: const _Stat(label: 'Following', value: '310'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.plus, size: 18, color: Colors.white),
                  label: const Text('Add story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D6FDC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D6FDC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Edit profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              const Text('Suggestions People',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestionsScreen())),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D6FDC),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF1D6FDC),
                    decorationThickness: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: kFriends.take(10).length,
              itemBuilder: (context, i) {
                final f = kFriends[i];
                final isFollowing = _followed.contains(f.handle);
                return Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEAEAEA)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.black,
                        child: Icon(LucideIcons.user, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        f.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        f.handle,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                if (isFollowing) {
                                  _followed.remove(f.handle);
                                } else {
                                  _followed.add(f.handle);
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing ? Colors.white : const Color(0xFF1D6FDC),
                              foregroundColor: isFollowing ? const Color(0xFF1D6FDC) : Colors.white,
                              side: BorderSide(color: const Color(0xFF1D6FDC)),
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 13)),
      ],
    );
  }
}


class UploadBanner extends StatelessWidget {
  const UploadBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UploadManager.instance,
      builder: (context, _) {
        final isUploading = UploadManager.instance.isUploading;
        final isSuccess = UploadManager.instance.isSuccess;
        final thumb = UploadManager.instance.thumbnailPath;
        final show = isUploading || isSuccess;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          top: show ? 8 : -100,
          left: 16,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(30),
            color: Colors.black,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (thumb != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(thumb),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        cacheWidth: 100,
                      ),
                    )
                  else
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(LucideIcons.image, color: Colors.white),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSuccess ? 'Successfully posted!' : 'Posting...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (isUploading)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSuccess)
                    const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
