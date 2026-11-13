import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'add_story_screen.dart';
import 'chat_screen.dart';
import 'dm_people_screens.dart';
import 'dm_sheets.dart';
import 'dm_theme.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'native_bridge.dart';
import 'post_model.dart';
import 'story_player_screen.dart';
import 'story_viewer_screen.dart';
import 'tag_friends_screen.dart';
import 'user_profile_screen.dart';

/// Instagram-style inbox: notes + stories row, Filters / Primary / Requests /
/// General, unread badges, message requests, and "Accounts to follow" at the bottom.
class MessagesTab extends StatefulWidget {
  /// Called by the back arrow (goes back to the feed).
  final VoidCallback? onBack;
  const MessagesTab({super.key, this.onBack});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  InboxTab _tab = InboxTab.primary;
  int _mask = 0;
  String _query = '';
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _filterCount {
    var n = 0;
    for (final f in const [kFlagUnread, kFlagUnanswered, kFlagStoryReply, kFlagFollowing, kFlagFollowsMe]) {
      if ((_mask & f) != 0) n++;
    }
    return n;
  }

  // ---------------------------------------------------------------- header

  Widget _header(DmColors c) {
    final handle = kMeHandle.replaceFirst('@', '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: c.text),
            onPressed: widget.onBack,
          ),
          Expanded(
            child: Text(handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.text, fontSize: 21, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            tooltip: 'Menu',
            icon: Icon(Icons.format_list_bulleted_rounded, color: c.text),
            onPressed: _openMenu,
          ),
          IconButton(
            tooltip: 'New message',
            icon: Icon(Icons.edit_square, color: c.text),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const NewMessageScreen())),
          ),
        ],
      ),
    );
  }

  void _openMenu() {
    final c = DmTheme.instance.c;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.sheet,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.mark_chat_read_outlined, color: c.text),
              title: Text('Mark all as read', style: TextStyle(color: c.text)),
              onTap: () {
                for (final h in ChatStore.instance.handles) {
                  ChatStore.instance.markRead(h);
                }
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: Icon(c.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: c.text),
              title: Text(c.dark ? 'Switch to light mode' : 'Switch to dark mode',
                  style: TextStyle(color: c.text)),
              onTap: () {
                DmTheme.instance.toggle();
                Navigator.pop(sheetContext);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- search

  Widget _searchBar(DmColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _search,
        cursorColor: c.text,
        style: TextStyle(color: c.text, fontSize: 16),
        onChanged: (v) => setState(() => _query = v.trim()),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: c.sub, fontSize: 16),
          prefixIcon: Icon(LucideIcons.search, color: c.sub, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(LucideIcons.x, color: c.sub, size: 18),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: c.field,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- notes row

  Widget _notesRow(DmColors c) {
    final notes = NoteStore.instance;
    final handles = <String>[
      ...notes.handlesWithNotes,
      for (final h in StoryStore.instance.otherHandles)
        if (notes.noteOf(h) == null) h,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _myNoteItem(c),
          for (final h in handles) _noteItem(c, h),
        ],
      ),
    );
  }

  Widget _noteBubble(DmColors c, String text, {bool dim = false}) {
    return Container(
      constraints: BoxConstraints(maxWidth: 84 * dmScale(context), minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: dim ? c.noteBubble : (c.dark ? const Color(0xFF2C3036) : const Color(0xFFEFEFEF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: dim ? c.noteText : c.text, fontSize: 11.5, height: 1.15),
      ),
    );
  }

  Widget _myNoteItem(DmColors c) {
    final note = NoteStore.instance.mine;
    final hasStory = StoryStore.instance.hasStory;
    final s = dmScale(context);
    return SizedBox(
      width: 88 * s,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => showNoteSheet(context),
            child: _noteBubble(c, note?.text ?? 'Make this space yours...', dim: note == null),
          ),
          const SizedBox(height: 3),
          GestureDetector(
            onTap: () {
              if (hasStory) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StoryViewerScreen()));
              } else {
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const AddStoryScreen()));
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                DmAvatar(handle: kMeHandle, size: 68 * s, ring: hasStory),
                if (!hasStory)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E7BFA),
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bg, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Your note',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.sub, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _noteItem(DmColors c, String handle) {
    final note = NoteStore.instance.noteOf(handle);
    final story = StoryStore.instance.otherStory(handle);
    final s = dmScale(context);
    void openStory() {
      if (story == null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(handle: handle)));
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryPlayerScreen(
            data: story.data,
            name: dmName(handle),
            handle: handle,
            time: story.time,
          ),
        ),
      );
    }

    return SizedBox(
      width: 88 * s,
      child: Column(
        children: [
          if (note != null)
            GestureDetector(
              onTap: () => showNoteReplySheet(context, handle),
              child: _noteBubble(c, note.text),
            )
          else
            const SizedBox(height: 36),
          const SizedBox(height: 3),
          GestureDetector(
            onTap: story != null
                ? openStory
                : () => showNoteReplySheet(context, handle),
            child: DmAvatar(handle: handle, size: 68 * s, ring: story != null),
          ),
          const SizedBox(height: 4),
          Text(dmName(handle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.sub, fontSize: 12)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- chips

  Widget _chip(DmColors c,
      {required String label, required bool selected, required VoidCallback onTap, Widget? trailing, Widget? leading}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? c.chipFill : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.chipFill : c.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 6)],
            Text(label,
                style: TextStyle(
                    color: c.text, fontWeight: FontWeight.w700, fontSize: 15)),
            if (trailing != null) ...[const SizedBox(width: 6), trailing],
          ],
        ),
      ),
    );
  }

  Widget _countDot(int n) => Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: DmTheme.instance.c.badge, borderRadius: BorderRadius.circular(9)),
        child: Text(n > 9 ? '9+' : '$n',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      );

  Widget _chips(DmColors c) {
    final store = ChatStore.instance;
    final requests = store.requestCount;
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 2),
        children: [
          _chip(
            c,
            label: _filterCount == 0 ? 'Filters' : 'Filters $_filterCount',
            selected: _filterCount > 0,
            leading: Icon(Icons.tune, size: 18, color: c.text),
            trailing: Icon(Icons.keyboard_arrow_down, size: 18, color: c.text),
            onTap: () => showFilterSheet(context, _mask, (m) => setState(() => _mask = m)),
          ),
          _chip(c,
              label: 'Primary',
              selected: _tab == InboxTab.primary,
              onTap: () => setState(() => _tab = InboxTab.primary)),
          _chip(c,
              label: 'Requests',
              selected: _tab == InboxTab.requests,
              trailing: requests > 0 ? _countDot(requests) : null,
              onTap: () => setState(() => _tab = InboxTab.requests)),
          _chip(c,
              label: 'General',
              selected: _tab == InboxTab.general,
              onTap: () => setState(() => _tab = InboxTab.general)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- rows

  void _openChat(String handle) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(handle: handle)));
  }

  void _openAvatar(String handle) {
    final story = StoryStore.instance.otherStory(handle);
    if (story == null) {
      _openChat(handle);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryPlayerScreen(
          data: story.data,
          name: dmName(handle),
          handle: handle,
          time: story.time,
        ),
      ),
    );
  }

  Widget _threadRow(DmColors c, String handle) {
    final store = ChatStore.instance;
    final last = store.last(handle);
    if (last == null) return const SizedBox.shrink();
    final unread = store.unread(handle);
    final isUnread = unread > 0;
    return InkWell(
      onTap: () => _openChat(handle),
      onLongPress: () => _threadMenu(handle),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _openAvatar(handle),
              child: DmAvatar(handle: handle, size: 62 * dmScale(context), ring: hasUnseenStory(handle)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dmName(handle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.text,
                          fontSize: 16,
                          fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text('${last.preview} · ${timeAgoLabel(last.time)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: isUnread ? c.text : c.sub,
                          fontSize: 14,
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400)),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 10),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c.badge, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _threadMenu(String handle) {
    final c = DmTheme.instance.c;
    final store = ChatStore.instance;
    final isUnread = store.unread(handle) > 0;
    final isRequest = store.bucketOf(handle) == InboxTab.requests;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.sheet,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            DmAvatar(handle: handle, size: 56),
            const SizedBox(height: 8),
            Text(dmName(handle),
                style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 6),
            if (isRequest)
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: c.text),
                title: Text('Accept request', style: TextStyle(color: c.text)),
                onTap: () {
                  store.accept(handle);
                  Navigator.pop(sheetContext);
                },
              ),
            ListTile(
              leading: Icon(isUnread ? Icons.drafts_outlined : Icons.mark_email_unread_outlined,
                  color: c.text),
              title: Text(isUnread ? 'Mark as read' : 'Mark as unread',
                  style: TextStyle(color: c.text)),
              onTap: () {
                isUnread ? store.markRead(handle) : store.markUnread(handle);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_outline, color: c.text),
              title: Text('View profile', style: TextStyle(color: c.text)),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(context, UserProfileScreen.route(personFor(handle)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete chat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                store.deleteThread(handle);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- lists

  /// Handles to show for the selected tab and filters (filters run in C++).
  List<String> _visibleThreads() {
    final store = ChatStore.instance;
    return [
      for (final h in store.handles)
        if (store.bucketOf(h) == _tab &&
            NativeCore.dmFilterPass(store.flagsOf(h), _mask))
          h
    ];
  }

  Widget _emptyState(DmColors c) {
    final filtered = _mask != 0;
    final text = filtered
        ? 'No chats match these filters'
        : switch (_tab) {
            InboxTab.primary => 'No messages yet',
            InboxTab.requests => 'No message requests',
            InboxTab.general => 'Nothing in General',
          };
    final sub = filtered
        ? null
        : switch (_tab) {
            InboxTab.primary => 'Send a message to start a chat.',
            InboxTab.requests =>
              "Messages from people you don't follow show up here. Follow them or accept to move the chat to Primary.",
            InboxTab.general => 'Quiet chats (no new messages for a week) move here.',
          };
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
      child: Column(
        children: [
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 16)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center, style: TextStyle(color: c.sub, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _suggestions(DmColors c) {
    final people = dmSuggestedPeople();
    if (people.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text('Accounts to follow',
                    style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DmSuggestionsScreen())),
                child: Text('See all',
                    style: TextStyle(color: c.blue, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        for (final p in people.take(5)) DmPersonRow(person: p),
      ],
    );
  }

  /// Search results: matching chats first, then other people.
  List<Widget> _searchResults(DmColors c) {
    final store = ChatStore.instance;
    final q = _query.toLowerCase();
    final chatHandles = store.handles;
    final people = [for (final p in kPeople) if (p.handle != kMeHandle) p];

    final chatHits = NativeCore.suggestSearch(
      [for (final h in chatHandles) '${dmName(h)} $h'.toLowerCase()].join('\n'),
      q,
      20,
    );
    final chatSet = {for (final h in chatHits) chatHandles[h.index]};
    final otherPeople = [for (final p in people) if (!chatSet.contains(p.handle)) p];
    final otherHits = NativeCore.suggestSearch(
      [for (final p in otherPeople) '${p.name} ${p.handle}'.toLowerCase()].join('\n'),
      q,
      20,
    );

    final out = <Widget>[];
    if (chatHits.isNotEmpty) {
      out.add(_sectionLabel(c, 'Chats'));
      for (final h in chatHits) {
        out.add(_threadRow(c, chatHandles[h.index]));
      }
    }
    if (otherHits.isNotEmpty) {
      out.add(_sectionLabel(c, 'More people'));
      for (final h in otherHits) {
        final p = otherPeople[h.index];
        out.add(DmPersonRow(
          person: p,
          trailing: const SizedBox.shrink(),
          onTap: () => _openChat(p.handle),
        ));
      }
    }
    if (out.isEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text('No results', style: TextStyle(color: c.sub))),
      ));
    }
    return out;
  }

  Widget _sectionLabel(DmColors c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(t,
            style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 16)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dmListenable(),
      builder: (context, _) {
        final c = DmTheme.instance.c;
        final searching = _query.isNotEmpty;
        final threads = searching ? const <String>[] : _visibleThreads();
        return Container(
          color: c.bg,
          child: Column(
            children: [
              _header(c),
              _searchBar(c),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: searching
                      ? _searchResults(c)
                      : [
                          _notesRow(c),
                          _chips(c),
                          const SizedBox(height: 6),
                          if (_tab == InboxTab.requests && threads.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                              child: Text(
                                "These are people you don't follow. Accept a request to move the chat to Primary.",
                                style: TextStyle(color: c.sub, fontSize: 13),
                              ),
                            ),
                          if (threads.isEmpty)
                            _emptyState(c)
                          else
                            for (final h in threads) _threadRow(c, h),
                          _suggestions(c),
                        ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
