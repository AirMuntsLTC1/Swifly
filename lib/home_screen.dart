import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _labels = [
    'Home',
    'Messages',
    'Notifications',
    'Profile',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _iconFor(int i) {
    switch (i) {
      case 0:
        return LucideIcons.home;
      case 1:
        return LucideIcons.messageCircle;
      case 2:
        return LucideIcons.bell;
      default:
        return LucideIcons.user;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Divider(height: 1, color: Color(0xFFEAEAEA)),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const [
                  FeedTab(),
                  MessagesTab(),
                  NotificationsTab(),
                  ProfileTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
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
                      cursorColor: Colors.black,
                      style: const TextStyle(color: Colors.black, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Search',
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
          const SizedBox(width: 2),
          for (int i = 0; i < 4; i++)
            IconButton(
              tooltip: _labels[i],
              onPressed: () => setState(() => _index = i),
              icon: Icon(_iconFor(i), color: Colors.black, size: 22),
              style: IconButton.styleFrom(
                backgroundColor:
                    _index == i ? const Color(0xFFE6E6E6) : Colors.transparent,
                minimumSize: const Size(40, 40),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

class FeedTab extends StatelessWidget {
  const FeedTab({super.key});

  static const List<Map<String, String>> _posts = [
    {'name': 'Ava Stone', 'handle': '@avastone', 'time': '2h', 'text': 'Sunrise hike done. Worth every step.'},
    {'name': 'Liam Park', 'handle': '@liampark', 'time': '4h', 'text': 'Just shipped my first app! Feedback welcome.'},
    {'name': 'Mia Chen', 'handle': '@miachen', 'time': '6h', 'text': 'New coffee spot downtown. Highly recommend.'},
    {'name': 'Noah Reed', 'handle': '@noahreed', 'time': '8h', 'text': 'Weekend project: a tiny plant-care tracker.'},
    {'name': 'Zara Ali', 'handle': '@zaraali', 'time': '1d', 'text': 'Books that changed how I think about design.'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEAEAEA)),
      itemBuilder: (context, i) {
        final p = _posts[i];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.black,
                child: Icon(LucideIcons.user, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(p['name']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, color: Colors.black)),
                        const SizedBox(width: 6),
                        Text('${p['handle']} · ${p['time']}',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF8E8E8E))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(p['text']!,
                        style: const TextStyle(
                            fontSize: 15, height: 1.4, color: Colors.black)),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(LucideIcons.heart, size: 19, color: Colors.black),
                        SizedBox(width: 22),
                        Icon(LucideIcons.messageCircle, size: 19, color: Colors.black),
                        SizedBox(width: 22),
                        Icon(LucideIcons.share2, size: 19, color: Colors.black),
                      ],
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
          trailing: Text(c['time']!, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
        );
      },
    );
  }
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  static const List<Map<String, dynamic>> _items = [
    {'icon': 0, 'text': 'Ava Stone liked your post'},
    {'icon': 1, 'text': 'Liam Park commented: "Nice work!"'},
    {'icon': 2, 'text': 'Mia Chen started following you'},
    {'icon': 0, 'text': 'Noah Reed liked your photo'},
  ];

  @override
  Widget build(BuildContext context) {
    const icons = [LucideIcons.heart, LucideIcons.messageCircle, LucideIcons.userPlus];
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEAEAEA)),
      itemBuilder: (context, i) {
        final n = _items[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(icons[n['icon'] as int], color: Colors.black),
          title: Text(n['text'] as String,
              style: const TextStyle(color: Colors.black, fontSize: 15)),
        );
      },
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 44,
            backgroundColor: Colors.black,
            child: Icon(LucideIcons.user, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 14),
          const Text('Your Name',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 4),
          const Text('@yourhandle',
              style: TextStyle(color: Color(0xFF8E8E8E))),
          const SizedBox(height: 10),
          const Text('Building something cool. Coffee and code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, height: 1.4)),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: 'Posts', value: '24'),
              _Stat(label: 'Followers', value: '1.2K'),
              _Stat(label: 'Following', value: '310'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(LucideIcons.pencil, size: 18, color: Colors.black),
              label: const Text('Edit profile',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
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
