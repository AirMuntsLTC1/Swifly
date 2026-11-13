import os
import shutil

def apply_fix(filepath, old_text, new_text, description):
    if not os.path.exists(filepath):
        print(f"❌ Could not find {filepath}")
        return
    
    shutil.copyfile(filepath, filepath + ".bak")
    
    with open(filepath, 'r') as f:
        content = f.read()
        
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ Fixed: {description}")
    else:
        print(f"⚠️ Skipped: {description} (code already changed or pattern not found)")

print("Applying Swifly Fixes v2...\n")

# --- FIX 1: Hide my own account from Home Profile Suggestions ---
apply_fix(
    "lib/home_screen.dart",
    """                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: kPeople.take(10).length,
                    itemBuilder: (context, i) => _suggestionCard(r, kPeople[i]),
                  ),""",
    """                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: kPeople.where((p) => p.handle != kMeHandle).take(10).length,
                    itemBuilder: (context, i) => _suggestionCard(r, kPeople.where((p) => p.handle != kMeHandle).toList()[i]),
                  ),""",
    "Hide own account in Home Suggestions"
)

# --- FIX 2: Hide my own account from User Profile Suggestions ---
apply_fix(
    "lib/user_profile_screen.dart",
    """              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: kPeople.take(10).length,
                itemBuilder: (context, i) {
                  final suggest = kPeople[i];""",
    """              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: kPeople.where((p) => p.handle != kMeHandle).take(10).length,
                itemBuilder: (context, i) {
                  final suggest = kPeople.where((p) => p.handle != kMeHandle).toList()[i];""",
    "Hide own account in Profile Suggestions"
)

# --- FIX 3: Hide my own account from 'See All' Suggestions Screen ---
apply_fix(
    "lib/suggestions_screen.dart",
    """      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kPeople.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFFEAEAEA)),
        itemBuilder: (context, i) {
          final p = kPeople[i];""",
    """      body: Builder(
        builder: (context) {
          final others = kPeople.where((p) => p.handle != kMeHandle).toList();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: others.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFFEAEAEA)),
            itemBuilder: (context, i) {
              final p = others[i];""",
    "Hide own account in 'See All' Suggestions"
)
# Fix the closing brackets for suggestions_screen.dart
apply_fix(
    "lib/suggestions_screen.dart",
    """          );
        },
      ),
    );
  }
}""",
    """              );
            },
          );
        },
      );
    }
  }""",
    "Fix brackets for suggestions screen"
)

# --- FIX 4: Hide my own account from Search Panel ---
apply_fix(
    "lib/discover_panel.dart",
    """            _title('People to follow'),
            for (final f in kPeople) _personTile(f),""",
    """            _title('People to follow'),
            for (final f in kPeople.where((p) => p.handle != kMeHandle)) _personTile(f),""",
    "Hide own account in Discover People to Follow"
)

apply_fix(
    "lib/discover_panel.dart",
    """    final people = kPeople
        .where((f) =>
            NativeCore.containsCI(f.name, q) ||
            NativeCore.containsCI(f.handle, q))
        .toList();""",
    """    final people = kPeople
        .where((f) => f.handle != kMeHandle)
        .where((f) =>
            NativeCore.containsCI(f.name, q) ||
            NativeCore.containsCI(f.handle, q))
        .toList();""",
    "Hide own account in Search Results"
)

# --- FIX 5: Fetch post_id and reply_to_id in messages ---
apply_fix(
    "lib/database_service.dart",
    """    final rows = await _db
        .from('messages')
        .select('id,sender,recipient,text,created_at')
        .or('sender.eq.$me,recipient.eq.$me')""",
    """    final rows = await _db
        .from('messages')
        .select('id,sender,recipient,text,reply_to_id,post_id,created_at')
        .or('sender.eq.$me,recipient.eq.$me')""",
    "Fetch post_id and reply_to_id from database"
)

apply_fix(
    "lib/database_service.dart",
    """      out.add({
        'id': '${r['id']}',
        'peer_handle': peer.handle,
        'text': '${r['text']}',
        'from_me': fromMe,
        'created_at': '${r['created_at']}',
      });""",
    """      out.add({
        'id': '${r['id']}',
        'peer_handle': peer.handle,
        'text': '${r['text']}',
        'from_me': fromMe,
        'created_at': '${r['created_at']}',
        'post_id': r['post_id'],
        'reply_to_id': r['reply_to_id'],
      });""",
    "Map post_id and reply_to_id in messages"
)

# --- FIX 6: Display placeholder text for empty messages (post shares/story replies) ---
apply_fix(
    "lib/db_mappers.dart",
    """  for (final r in rows) {
    out.putIfAbsent(_s(r['peer_handle']), () => <ChatMessage>[]).add(ChatMessage(
          id: _s(r['id']).isEmpty ? null : _s(r['id']),
          text: _s(r['text']),
          fromMe: _b(r['from_me']),
          time: _t(r['created_at']),
        ));
  }""",
    """  for (final r in rows) {
    final text = _s(r['text']);
    final postId = r['post_id'];
    final replyToId = r['reply_to_id'];
    String displayText = text;
    
    if (displayText.isEmpty) {
      if (postId != null) displayText = "Shared a post";
      else if (replyToId != null) displayText = "Replied to a message";
      else displayText = "Story reply";
    }

    out.putIfAbsent(_s(r['peer_handle']), () => <ChatMessage>[]).add(ChatMessage(
          id: _s(r['id']).isEmpty ? null : _s(r['id']),
          text: displayText,
          fromMe: _b(r['from_me']),
          time: _t(r['created_at']),
        ));
  }""",
    "Prevent empty bubbles by adding 'Shared a post' text"
)

print("\nAll fixes applied successfully! You can now rebuild the app.")
