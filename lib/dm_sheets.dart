import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'dm_theme.dart';
import 'inbox_store.dart';
import 'post_model.dart';
import 'people_directory.dart';

const int kNoteMax = 60;

/// Sheet to write, replace or delete MY note.
Future<void> showNoteSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DmTheme.instance.c.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _NoteSheet(),
  );
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet();

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: NoteStore.instance.mine?.text ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DmTheme.instance.c;
    final has = NoteStore.instance.mine != null;
    final canShare = _controller.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration:
                BoxDecoration(color: c.chipBorder, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: c.text, fontSize: 15)),
              ),
              Expanded(
                child: Center(
                  child: Text('New note',
                      style: TextStyle(
                          color: c.text, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
              TextButton(
                onPressed: canShare
                    ? () {
                        NoteStore.instance.setMine(_controller.text);
                        Navigator.pop(context);
                      }
                    : null,
                child: Text('Share',
                    style: TextStyle(
                        color: canShare ? c.blue : c.sub,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DmAvatar(handle: kMeHandle, size: 84),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: kNoteMax,
            maxLines: 2,
            minLines: 1,
            cursorColor: c.text,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.text, fontSize: 16),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Share a thought...',
              hintStyle: TextStyle(color: c.sub),
              counterStyle: TextStyle(color: c.sub),
              filled: true,
              fillColor: c.field,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('Shared with people who follow you. Disappears after 24 hours.',
              textAlign: TextAlign.center, style: TextStyle(color: c.sub, fontSize: 12)),
          if (has) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                NoteStore.instance.deleteMine();
                Navigator.pop(context);
              },
              child: const Text('Delete note',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sheet to reply to somebody else's note. The reply lands in their chat.
Future<void> showNoteReplySheet(BuildContext context, String handle) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DmTheme.instance.c.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _NoteReplySheet(handle: handle),
  );
}

class _NoteReplySheet extends StatefulWidget {
  final String handle;
  const _NoteReplySheet({required this.handle});

  @override
  State<_NoteReplySheet> createState() => _NoteReplySheetState();
}

class _NoteReplySheetState extends State<_NoteReplySheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    final note = NoteStore.instance.noteOf(widget.handle);
    if (text.isEmpty || note == null) return;
    ChatStore.instance.send(
      widget.handle,
      text,
      replyTo: ReplyRef(
        messageId: 'note-${note.time.millisecondsSinceEpoch}',
        text: note.text,
        fromMe: false,
        authorName: dmName(widget.handle),
        authorHandle: widget.handle,
        kind: ReplyKind.note,
      ),
    );
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => ChatScreen(handle: widget.handle)));
  }

  @override
  Widget build(BuildContext context) {
    final c = DmTheme.instance.c;
    final note = NoteStore.instance.noteOf(widget.handle);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration:
                BoxDecoration(color: c.chipBorder, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.noteBubble,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(note?.text ?? 'This note has expired',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text, fontSize: 15)),
          ),
          const SizedBox(height: 10),
          DmAvatar(handle: widget.handle, size: 76),
          const SizedBox(height: 8),
          Text(dmName(widget.handle),
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 14),
          if (note != null)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    cursorColor: c.text,
                    style: TextStyle(color: c.text),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Reply to ${dmName(widget.handle)}...',
                      hintStyle: TextStyle(color: c.sub),
                      filled: true,
                      fillColor: c.field,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _send,
                  child: Text('Send',
                      style: TextStyle(color: c.blue, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The Filters sheet. Calls [onChanged] on every tap so the inbox updates live.
Future<void> showFilterSheet(
    BuildContext context, int mask, ValueChanged<int> onChanged) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: DmTheme.instance.c.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FilterSheet(initial: mask, onChanged: onChanged),
  );
}

class _FilterSheet extends StatefulWidget {
  final int initial;
  final ValueChanged<int> onChanged;
  const _FilterSheet({required this.initial, required this.onChanged});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late int _mask = widget.initial;
  bool _more = false;

  static const _main = <(int, IconData, String)>[
    (kFlagUnread, Icons.mark_email_unread_outlined, 'Unread'),
    (kFlagUnanswered, Icons.help_outline, 'Unanswered'),
    (kFlagStoryReply, Icons.motion_photos_on_outlined, 'Story replies'),
  ];
  static const _extra = <(int, IconData, String)>[
    (kFlagFollowing, Icons.how_to_reg_outlined, 'People you follow'),
    (kFlagFollowsMe, Icons.person_add_alt_outlined, 'People who follow you'),
  ];

  void _toggle(int flag) {
    setState(() => _mask = (_mask & flag) != 0 ? (_mask & ~flag) : (_mask | flag));
    widget.onChanged(_mask);
  }

  Widget _row((int, IconData, String) item) {
    final c = DmTheme.instance.c;
    final on = (_mask & item.$1) != 0;
    return InkWell(
      onTap: () => _toggle(item.$1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(item.$2, color: c.text, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Text(item.$3, style: TextStyle(color: c.text, fontSize: 17)),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? c.blue : Colors.transparent,
                border: Border.all(color: on ? c.blue : c.sub, width: 2),
              ),
              child: on ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DmTheme.instance.c;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: c.chipBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Filters',
                      style: TextStyle(
                          color: c.text, fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                if (_mask != 0)
                  TextButton(
                    onPressed: () {
                      setState(() => _mask = 0);
                      widget.onChanged(0);
                    },
                    child: Text('Clear',
                        style: TextStyle(color: c.blue, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          for (final i in _main) _row(i),
          if (_more) for (final i in _extra) _row(i),
          if (!_more)
            InkWell(
              onTap: () => setState(() => _more = true),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Text('See more', style: TextStyle(color: c.sub, fontSize: 17)),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
