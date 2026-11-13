import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'count_badge.dart';
import 'create_sheet.dart';
import 'discover_panel.dart';
import 'feed_widgets.dart';
import 'post_model.dart';
import 'follow_button.dart';
import 'follow_store.dart';
import 'add_story_screen.dart';
import 'edit_profile_screen.dart';
import 'inbox_store.dart';
import 'responsive.dart';
import 'story_viewer_screen.dart';
import 'user_profile_screen.dart';
import 'profile_details_section.dart';
import 'profile_store.dart';
import 'connections_screen.dart';
import 'suggestions_screen.dart';
import 'search_history.dart';
import 'upload_manager.dart';
import 'tag_friends_screen.dart';
import 'messages_tab.dart';
import 'dm_theme.dart';
import 'package:flutter/services.dart';
import 'notifications_tab.dart';

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
  void initState() {
    super.initState();
    DmTheme.instance.addListener(_onDmTheme);
  }

  void _onDmTheme() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DmTheme.instance.removeListener(_onDmTheme);
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
    final onMessages = _index == 1;
    final dm = DmTheme.instance.c;
    return PopScope(
      canPop: !_searchOpen && !onMessages,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_searchOpen) {
          _closeSearch();
        } else if (onMessages) {
          _selectTab(0);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: onMessages && dm.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
      backgroundColor: onMessages ? dm.bg : Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
          children: [
            // Messages has its own Instagram-style header with a back arrow.
            if (!onMessages) ...[
              _buildTopBar(),
              const Divider(height: 1, color: Color(0xFFEAEAEA)),
            ],
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(
                    index: _index,
                    children: [
                      const FeedTab(),
                      MessagesTab(onBack: () => _selectTab(0)),
                      const NotificationsTab(),
                      const ProfileTab(),
                    ],
                  ),
                  _buildDiscoverOverlay(),
                ],
              ),
            ),
          ],
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: UploadBanner(),
            ),
          ),
        ],
      ),
      floatingActionButton: onMessages ? null : FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: () => showCreateSheet(context),
        child: const Icon(LucideIcons.plus, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
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
                // Red unread count on the bell.
                if (i == 1) const Positioned(top: 2, right: 2, child: _MessageBadge()),
                if (i == 2) const Positioned(top: 2, right: 2, child: UnreadBadge()),
              ],
            ),
          ),
      ],
    );
  }
}

/// Red count on the Messages icon: conversations with something unread.
class _MessageBadge extends StatelessWidget {
  const _MessageBadge();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ChatStore.instance,
      builder: (context, _) => CountBadge(
        count: ChatStore.instance.unreadThreads,
        borderColor: Colors.white,
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  void initState() {
    super.initState();
    ProfileStore.instance.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    ProfileStore.instance.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }


  Future<void> _addStory() async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddStoryScreen()),
    );
    if (posted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your story is live')),
      );
    }
  }

  Widget _avatar(R r) {
    final path = ProfileStore.instance.avatarPath;
    final hasStory = StoryStore.instance.hasStory;
    final radius = r.s(44);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.black,
      backgroundImage: path == null ? null : FileImage(File(path)),
      child: path == null ? Icon(LucideIcons.user, color: Colors.white, size: r.s(40)) : null,
    );
    return GestureDetector(
      onTap: () {
        if (hasStory) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const StoryViewerScreen()));
        } else {
          Navigator.push(context, editProfileRoute());
        }
      },
      child: hasStory
          ? Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1D6FDC), width: 3),
              ),
              child: avatar,
            )
          : avatar,
    );
  }

  Widget _suggestionCard(R r, Person f) {
    return GestureDetector(
      onTap: () => Navigator.push(context, UserProfileScreen.route(f)),
      child: Container(
        width: r.w(130),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAEAEA)),
        ),
        child: Column(
          children: [
            SizedBox(height: r.h(12)),
            CircleAvatar(
              radius: r.s(30),
              backgroundColor: Colors.black,
              child: Icon(LucideIcons.user, color: Colors.white, size: r.s(30)),
            ),
            SizedBox(height: r.h(8)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                f.name,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                f.handle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FollowButton(handle: f.handle, compact: true, expand: true),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final bio = ProfileStore.instance.fieldFor('bio').value;
    return ListenableBuilder(
      listenable: StoryStore.instance,
      builder: (context, _) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(0, r.h(20), 0, r.h(96)),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              _avatar(r),
              SizedBox(height: r.h(14)),
              const Text(kMeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black)),
              const SizedBox(height: 4),
              const Text(kMeHandle, style: TextStyle(color: Color(0xFF8E8E8E))),
              SizedBox(height: r.h(10)),
              GestureDetector(
                onTap: () => Navigator.push(context, fieldEditorRoute(kProfileSections.first.fields.first)),
                child: Text(
                  bio.isEmpty ? 'Add a bio' : bio,
                  style: TextStyle(
                      color: bio.isEmpty ? const Color(0xFF8E8E8E) : Colors.black, height: 1.4),
                ),
              ),
              SizedBox(height: r.h(20)),
              ListenableBuilder(
                listenable: FollowStore.instance,
                builder: (context, _) => FlexRow(
                  spacing: r.w(32),
                  children: [
                    const _Stat(label: 'Posts', value: '24'),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ConnectionsScreen(initialFollowers: true))),
                      child: _Stat(
                          label: 'Followers',
                          value: '${FollowStore.instance.followerHandles.length}'),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ConnectionsScreen(initialFollowers: false))),
                      child: _Stat(
                          label: 'Following',
                          value: '${FollowStore.instance.followingHandles.length}'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.h(20)),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addStory,
                      icon: const Icon(LucideIcons.plus, size: 18, color: Colors.white),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Add story',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D6FDC),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: EdgeInsets.symmetric(vertical: r.h(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, editProfileRoute()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D6FDC),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: EdgeInsets.symmetric(vertical: r.h(12)),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Update profile',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.h(24)),
              const ProfileDetailsSection(),
              SizedBox(height: r.h(30)),
              Row(
                children: [
                  const Expanded(
                    child: Text('Suggestions People',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const SuggestionsScreen())),
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
              SizedBox(height: r.h(12)),
              ListenableBuilder(
                listenable: PostStore.instance,
                builder: (context, _) => SizedBox(
                  height: r.h(190),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: kPeople.take(10).length,
                    itemBuilder: (context, i) => _suggestionCard(r, kPeople[i]),
                  ),
                ),
              ),
                  ],
                ),
              ),
              SizedBox(height: r.h(26)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.pad),
                child: const Text('Posts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
              ),
              const SizedBox(height: 6),
              ListenableBuilder(
                listenable: PostStore.instance,
                builder: (context, _) {
                  final mine = PostStore.instance.myPosts;
                  if (mine.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.pad, vertical: 16),
                      child: const Text('No posts yet. Tap + to share your first post.',
                          style: TextStyle(color: Color(0xFF8E8E8E))),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in mine) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(r.pad, 12, r.pad, 0),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.calendar, size: 15, color: Color(0xFF65676B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Posted ${_postStamp(p.created)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF65676B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PostCard(key: ValueKey('mine-${p.id}'), post: p),
                        const Divider(height: 1, color: Color(0xFFEAEAEA)),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Thursday, Nov 12, 2026 at 7:21 PM"
String _postStamp(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  return '${_weekdays[t.weekday - 1]}, ${_months[t.month - 1]} ${t.day}, ${t.year} at $h12:$mm $ampm';
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

        return AnimatedSlide(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          offset: show ? Offset.zero : const Offset(0, -2),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(LucideIcons.image, color: Colors.white),
                        ),
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
                    const Icon(LucideIcons.circleCheck, color: Colors.green, size: 20),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}
