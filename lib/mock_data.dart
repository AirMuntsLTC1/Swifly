import 'app_config.dart';
import 'follow_store.dart';
import 'profile_store.dart';
import 'inbox_store.dart';
import 'post_model.dart';
import 'story_models.dart';

/// ALL mock/test data lives in this file.
/// To go live: set kUseMockData = false in app_config.dart, and delete this file
/// and mock_realtime.dart. Nothing else in the app refers to mock data directly.

List<Post> mockPosts() {
  final now = DateTime.now();
  final out = <Post>[];
    out.add(
      Post(
        id: kMyPostId,
        authorName: kMeName,
        authorHandle: kMeHandle,
        text: 'My first post on Swifly! #hello',
        audience: 'Everyone',
        created: now.subtract(const Duration(hours: 3)),
        likes: 5,
        saves: 1,
        comments: [
          CommentItem(
            id: 'demo-c1',
            name: 'Liam Park',
            text: 'Welcome to Swifly!',
            created: now.subtract(const Duration(minutes: 30)),
          ),
        ],
      ),
    );
    out.addAll([
      Post(
        id: 's1',
        authorName: 'Ava Stone',
        authorHandle: '@avastone',
        text: 'Sunrise hike done. Worth every step. #hiking #travel',
        audience: 'Everyone',
        taggedHandles: const ['@liampark'],
        created: now.subtract(const Duration(hours: 2)),
        likes: 42,
        saves: 6,
        comments: [
          CommentItem(name: 'Liam Park', text: 'Looks amazing!', created: now),
        ],
      ),
      Post(
        id: 's2',
        authorName: 'Liam Park',
        authorHandle: '@liampark',
        text: 'Just shipped my first app! Feedback welcome. #coding #design',
        audience: 'Followers',
        taggedHandles: const ['@avastone', '@noahreed'],
        created: now.subtract(const Duration(hours: 4)),
        likes: 88,
        saves: 12,
      ),
      Post(
        id: 's3',
        authorName: 'Mia Chen',
        authorHandle: '@miachen',
        text: 'New coffee spot downtown. Highly recommend. #coffee',
        audience: 'Everyone',
        created: now.subtract(const Duration(hours: 6)),
        likes: 19,
        saves: 3,
      ),
      Post(
        id: 's4',
        authorName: 'Noah Reed',
        authorHandle: '@noahreed',
        text: 'Weekend project: a tiny plant-care tracker. #coding',
        audience: 'Followers',
        taggedHandles: const ['@zaraali'],
        created: now.subtract(const Duration(hours: 8)),
        likes: 7,
        saves: 1,
      ),
      Post(
        id: 's5',
        authorName: 'Zara Ali',
        authorHandle: '@zaraali',
        text: 'Books that changed how I think about design. #books #design',
        audience: 'Everyone',
        taggedHandles: const ['@hanasato'],
        created: now.subtract(const Duration(days: 1)),
        likes: 130,
        saves: 25,
      ),
    ]);
  return out;
}

/// Loads sample posts, people, notifications, chats and story into the stores.
void loadMockData() {
  if (!kUseMockData) return;
  final now = DateTime.now();

  PostStore.instance.load(posts: mockPosts());
  FollowStore.instance.load(
    following: {'@liampark', '@zaraali'},
    followers: {'@avastone', '@zaraali'},
  );

  NotificationStore.instance.load([
    AppNotification(
      id: 'n1',
      type: NotifType.like,
      actorName: 'Ava Stone',
      actorHandle: '@avastone',
      postId: kMyPostId,
      created: now.subtract(const Duration(minutes: 10)),
    ),
    AppNotification(
      id: 'n2',
      type: NotifType.comment,
      actorName: 'Liam Park',
      actorHandle: '@liampark',
      postId: kMyPostId,
      commentId: 'demo-c1',
      preview: 'Welcome to Swifly!',
      created: now.subtract(const Duration(minutes: 30)),
    ),
    AppNotification(
      id: 'n3',
      type: NotifType.follow,
      actorName: 'Mia Chen',
      actorHandle: '@miachen',
      created: now.subtract(const Duration(hours: 1)),
    ),
    AppNotification(
      id: 'n4',
      type: NotifType.message,
      actorName: 'Ava Stone',
      actorHandle: '@avastone',
      preview: 'See you at the hike!',
      created: now.subtract(const Duration(hours: 2)),
      read: true,
    ),
    AppNotification(
      id: 'n5',
      type: NotifType.storyReact,
      actorName: 'Noah Reed',
      actorHandle: '@noahreed',
      emoji: '🔥',
      created: now.subtract(const Duration(hours: 3)),
      read: true,
    ),
    AppNotification(
      id: 'n6',
      type: NotifType.tag,
      actorName: 'Kai Ramzy',
      actorHandle: '@kairamzy',
      postId: kMyPostId,
      created: now.subtract(const Duration(minutes: 45)),
    ),
    AppNotification(
      id: 'n8',
      type: NotifType.save,
      actorName: 'Biao Deay',
      actorHandle: '@biaodeay',
      postId: kMyPostId,
      created: now.subtract(const Duration(days: 1, hours: 3)),
      read: true,
    ),
  ]);

  ChatStore.instance.load({
    '@avastone': [
      ChatMessage(text: 'Did you see the sunrise pics?', fromMe: false,
          time: now.subtract(const Duration(days: 1))),
      ChatMessage(text: 'See you at the hike!', fromMe: false,
          time: now.subtract(const Duration(hours: 2))),
    ],
    '@liampark': [
      ChatMessage(text: 'Check out my new build', fromMe: false,
          time: now.subtract(const Duration(hours: 8))),
    ],
    '@miachen': [
      ChatMessage(text: 'Coffee on Saturday?', fromMe: false,
          time: now.subtract(const Duration(days: 1))),
    ],
  });

  ProfileStore.instance.load({
    'bio': ProfileField(value: 'Building something cool. Coffee and code.', audience: Audience.everyone),
    'birthday': ProfileField(value: '2005-03-28', audience: Audience.followers),
    'gender': ProfileField(value: 'Male', audience: Audience.onlyMe),
    'socialMedia': ProfileField(value: 'olid_xspace', audience: Audience.everyone),
  });

  StoryStore.instance.load(
    caption: 'My weekend so far',
    reactions: [
      StoryReaction(name: 'Noah Reed', handle: '@noahreed', emoji: '🔥',
          time: now.subtract(const Duration(hours: 3))),
    ],
  );

  StoryStore.instance.loadOthers({
    '@liampark': OtherStory(
      time: now.subtract(const Duration(hours: 2)),
      data: StoryData(bgColor: 0xFF8E24AA, layers: [
        StoryLayer(id: 'a1', kind: StoryLayerKind.text, text: 'Shipping day!', dy: 0.38),
        StoryLayer(id: 'a2', kind: StoryLayerKind.sticker, text: 'rocket', dy: 0.55, scale: 1.8),
        StoryLayer(id: 'a3', kind: StoryLayerKind.place,
            text: 'Zone 2, Brgy. Poblacion, Davao City', dy: 0.82),
      ]),
    ),
    '@avastone': OtherStory(
      time: now.subtract(const Duration(hours: 1)),
      data: StoryData(bgColor: 0xFFE8710A, layers: [
        StoryLayer(id: 'b1', kind: StoryLayerKind.text, text: 'Sunrise hike done', dy: 0.4),
        StoryLayer(id: 'b2', kind: StoryLayerKind.sticker, text: 'sun', dy: 0.58, scale: 2),
      ]),
    ),
    '@zaraali': OtherStory(
      time: now.subtract(const Duration(hours: 5)),
      data: StoryData(bgColor: 0xFF00897B, layers: [
        StoryLayer(id: 'c1', kind: StoryLayerKind.text, text: 'Reading day', dy: 0.4),
        StoryLayer(id: 'c2', kind: StoryLayerKind.sticker, text: 'sparkles', dy: 0.58, scale: 1.8),
      ]),
    ),
  });
}

