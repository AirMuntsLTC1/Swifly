import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'chat_screen.dart';
import 'dm_theme.dart';
import 'follow_store.dart';
import 'inbox_store.dart';
import 'native_bridge.dart';
import 'post_model.dart';
import 'tag_friends_screen.dart';
import 'user_profile_screen.dart';

/// Follow / Follow back / Following button in the Messages (Instagram) style.
class DmFollowButton extends StatelessWidget {
  final String handle;
  const DmFollowButton({super.key, required this.handle});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([FollowStore.instance, DmTheme.instance]),
      builder: (context, _) {
        final c = DmTheme.instance.c;
        final state = FollowStore.instance.stateOf(handle);
        final following = state == FollowState.following || state == FollowState.mutual;
        return GestureDetector(
          onTap: () async {
            if (!following) {
              FollowStore.instance.follow(handle);
              return;
            }
            final ok = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                backgroundColor: c.sheet,
                title: Text('Unfollow ${dmName(handle)}?', style: TextStyle(color: c.text)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(d, false),
                    child: Text('Cancel', style: TextStyle(color: c.text)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('Unfollow',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
            if (ok == true) FollowStore.instance.unfollow(handle);
          },
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: following ? c.chipFill : const Color(0xFF3E7BFA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              followLabel(state),
              style: TextStyle(
                color: following ? c.text : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// People I do not follow yet, people who follow me first (C++ ranking).
List<Person> dmSuggestedPeople() {
  final list = [
    for (final p in kPeople)
      if (p.handle != kMeHandle && !FollowStore.instance.isFollowing(p.handle)) p
  ];
  final order = NativeCore.dmRankPeople(
    [for (final p in list) FollowStore.instance.isFollower(p.handle)],
    [for (final p in list) hasUnseenStory(p.handle) ? 1 : 0],
  );
  return [for (final i in order) list[i]];
}

/// One row of "Accounts to follow".
class DmPersonRow extends StatelessWidget {
  final Person person;
  final Widget? trailing;
  final VoidCallback? onTap;
  const DmPersonRow({super.key, required this.person, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = DmTheme.instance.c;
    final followsMe = FollowStore.instance.isFollower(person.handle);
    return InkWell(
      onTap: onTap ??
          () => Navigator.push(context, UserProfileScreen.route(person)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            DmAvatar(
                handle: person.handle,
                size: 52 * dmScale(context),
                ring: hasUnseenStory(person.handle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.text, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(followsMe ? '${person.handle} · Follows you' : person.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.sub, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ?? DmFollowButton(handle: person.handle),
          ],
        ),
      ),
    );
  }
}

/// "See all" from the bottom of the inbox.
class DmSuggestionsScreen extends StatelessWidget {
  const DmSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dmListenable(),
      builder: (context, _) {
        final c = DmTheme.instance.c;
        final people = dmSuggestedPeople();
        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            backgroundColor: c.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(LucideIcons.arrowLeft, color: c.text),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Accounts to follow',
                style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          body: people.isEmpty
              ? Center(
                  child: Text("You're following everyone suggested",
                      style: TextStyle(color: c.sub)))
              : ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  children: [for (final p in people) DmPersonRow(person: p)],
                ),
        );
      },
    );
  }
}

/// Compose button: pick a person to start a chat with.
class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Person> _people() {
    final all = [for (final p in kPeople) if (p.handle != kMeHandle) p];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      // People I follow first, then the rest.
      final order = NativeCore.dmRankPeople(
        [for (final p in all) FollowStore.instance.isFollowing(p.handle)],
        [for (final p in all) ChatStore.instance.hasThread(p.handle) ? 5 : 0],
      );
      return [for (final i in order) all[i]];
    }
    final joined = [for (final p in all) '${p.name} ${p.handle}'.toLowerCase()].join('\n');
    final hits = NativeCore.suggestSearch(joined, q, 30);
    return [for (final h in hits) all[h.index]];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dmListenable(),
      builder: (context, _) {
        final c = DmTheme.instance.c;
        final people = _people();
        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            backgroundColor: c.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(LucideIcons.x, color: c.text),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('New message',
                style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  cursorColor: c.text,
                  style: TextStyle(color: c.text),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: c.sub),
                    prefixIcon: Icon(LucideIcons.search, color: c.sub, size: 20),
                    filled: true,
                    fillColor: c.field,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: people.isEmpty
                    ? Center(child: Text('No account found', style: TextStyle(color: c.sub)))
                    : ListView(
                        children: [
                          for (final p in people)
                            DmPersonRow(
                              person: p,
                              trailing: const SizedBox.shrink(),
                              onTap: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ChatScreen(handle: p.handle)),
                              ),
                            ),
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
