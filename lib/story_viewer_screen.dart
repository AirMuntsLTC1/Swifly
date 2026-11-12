import 'dart:io';

import 'package:flutter/material.dart';

import 'inbox_store.dart';

/// Shows the user's story and everyone who reacted. [highlightHandle] marks
/// the reaction that opened this screen from a notification.
class StoryViewerScreen extends StatelessWidget {
  final String? highlightHandle;
  const StoryViewerScreen({super.key, this.highlightHandle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Your story',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Delete story',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              StoryStore.instance.delete();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: StoryStore.instance,
        builder: (context, _) {
          final store = StoryStore.instance;
          return Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: store.imagePath == null ? Color(store.bgColor) : Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (store.imagePath != null)
                        Image.file(
                          File(store.imagePath!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      if (store.caption.isNotEmpty)
                        Align(
                          alignment: store.imagePath == null
                              ? Alignment.center
                              : Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              store.caption,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${store.reactions.length} reactions',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.26,
                      child: ListView(
                        children: [
                          for (final r in store.reactions)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: r.handle == highlightHandle
                                    ? const Color(0xFF3A3A3A)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Text(r.emoji, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(r.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  Text(timeAgoLabel(r.time),
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


