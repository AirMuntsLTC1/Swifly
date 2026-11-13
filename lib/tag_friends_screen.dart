import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'people_directory.dart';


/// Slides up full screen. Pops with the selected handles, or null if cancelled.
Route<List<String>> tagFriendsRoute(List<String> initial) {
  return PageRouteBuilder<List<String>>(
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => TagFriendsScreen(initial: initial),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(curved),
        child: child,
      );
    },
  );
}

class TagFriendsScreen extends StatefulWidget {
  final List<String> initial;
  const TagFriendsScreen({super.key, required this.initial});

  @override
  State<TagFriendsScreen> createState() => _TagFriendsScreenState();
}

class _TagFriendsScreenState extends State<TagFriendsScreen> {
  late final Set<String> _selected;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initial};
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = kPeople.where((f) {
      return f.name.toLowerCase().contains(_query) ||
          f.handle.toLowerCase().contains(_query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.search, size: 20, color: Colors.black),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              cursorColor: Colors.black,
                              style: const TextStyle(color: Colors.black, fontSize: 15),
                              decoration: const InputDecoration(
                                hintText: 'Search people',
                                hintStyle: TextStyle(color: Color(0xFF8E8E8E)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selected.toList()),
                    child: Text(
                      'Done${_selected.isEmpty ? '' : ' (${_selected.length})'}',
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAEAEA)),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No people found',
                          style: TextStyle(color: Color(0xFF8E8E8E))),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFEAEAEA)),
                      itemBuilder: (context, i) {
                        final f = filtered[i];
                        final isSelected = _selected.contains(f.handle);
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          onTap: () => setState(() {
                            isSelected
                                ? _selected.remove(f.handle)
                                : _selected.add(f.handle);
                          }),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.black,
                            child: Icon(LucideIcons.user, color: Colors.white, size: 20),
                          ),
                          title: Text(f.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, color: Colors.black)),
                          subtitle: Text(f.handle,
                              style: const TextStyle(color: Color(0xFF8E8E8E))),
                          trailing: Icon(
                            isSelected ? LucideIcons.circleCheck : LucideIcons.circle,
                            color: isSelected ? Colors.black : const Color(0xFFBDBDBD),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


