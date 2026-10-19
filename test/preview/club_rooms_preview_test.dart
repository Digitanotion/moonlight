// Design previews of the club rooms, rendered from the real widgets with
// sample people. Off by default; to (re)generate the PNGs:
//
//   MOONLIGHT_PREVIEW=1 flutter test test/preview --update-goldens
//
// Images land in test/preview/goldens/.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/clubs/rooms/club_room_models.dart';
import 'package:moonlight/features/clubs/rooms/room_stage.dart';

final _enabled = Platform.environment['MOONLIGHT_PREVIEW'] == '1';

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  const u = 'assets/fonts/Urbanist/Urbanist-';
  await family('Urbanist', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) '$u$w.ttf',
  ]);
  await family('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

// ── sample data ─────────────────────────────────────────────────────────

const _names = [
  'Amaefuna', 'Clem', 'Ezeogbo Mmasi', 'Sharpito', 'You', 'Uche',
  'Nkechi', 'Ebuka', 'Omalicha', 'Ada', 'Chidi', 'Ifeoma', 'Tobi',
];

RoomParticipant _p(
  int i, {
  String role = 'speaker',
  bool muted = true,
  bool lady = false,
  bool visible = true,
  bool premium = false,
}) {
  final name = _names[i % _names.length];
  return RoomParticipant(
    user: RoomUser(
      uuid: name == 'You' ? 'me' : 'u$i',
      uid: i + 1,
      display: name,
      isLady: lady,
      isHost: role == 'host',
    ),
    role: role,
    micMuted: muted,
    videoPremium: premium,
    videoVisible: visible,
  );
}

RoomState _state(
  RoomType type,
  List<RoomParticipant> people, {
  String title = 'Okpuno 2 BRC old and new members',
  RoomPremium premium = const RoomPremium(),
}) => RoomState(
  uuid: 'r',
  type: type,
  status: 'live',
  title: title,
  clubUuid: 'c',
  clubName: 'Okpuno 2 BRC',
  host: people.first.user,
  capacity: type == RoomType.audio ? 20 : 10,
  freeSlots: 10,
  freeSlotsLeft: 0,
  entryFeeCoins: 10,
  premium: premium,
  startedAt: DateTime.now().subtract(const Duration(minutes: 55, seconds: 19)),
  participants: people,
  seatRequests: const [],
  me: const RoomMe(inRoom: true, role: 'guest'),
);

// Stand-in "camera" frames: soft gradients with a silhouette.
const _cams = [
  [Color(0xFF3A6073), Color(0xFF16222A)],
  [Color(0xFFB06AB3), Color(0xFF4568DC)],
  [Color(0xFFE29587), Color(0xFFD66D75)],
  [Color(0xFF2C5364), Color(0xFF0F2027)],
  [Color(0xFFF2994A), Color(0xFFF2C94C)],
  [Color(0xFF56AB2F), Color(0xFFA8E063)],
  [Color(0xFF614385), Color(0xFF516395)],
  [Color(0xFFEB5757), Color(0xFF000000)],
  [Color(0xFF00B4DB), Color(0xFF0083B0)],
  [Color(0xFFDA4453), Color(0xFF89216B)],
];

Widget _fakeCamera(RoomParticipant p) {
  final c = _cams[p.user.uid % _cams.length];
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: c,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: LayoutBuilder(
      builder: (_, box) => Align(
        alignment: const Alignment(0, 1.25),
        child: Icon(
          Icons.person_rounded,
          size: box.biggest.shortestSide * 0.95,
          color: Colors.white.withValues(alpha: 0.32),
        ),
      ),
    ),
  );
}

Widget _comments() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final (who, text) in const [
      ('Nkechi', 'Good evening everyone 🌙'),
      ('Ebuka', 'Amaefuna abeg say am again 😂'),
    ])
      Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$who  ',
                style: const TextStyle(
                  color: MoonColors.ember,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: text),
            ],
          ),
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
        ),
      ),
  ],
);

void _noop() {}

Widget _app(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark().copyWith(
    textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Urbanist'),
  ),
  home: Scaffold(body: child),
);

Widget _audio(List<RoomParticipant> people, Set<int> speaking) =>
    AudioRoomView(
      state: _state(RoomType.audio, people),
      myUuid: 'me',
      isSpeaking: (p) => speaking.contains(p.user.uid),
      isMuted: (p) => p.micMuted,
      micMuted: true,
      speakerOn: true,
      onCollapse: _noop,
      onParticipants: _noop,
      onTapParticipant: (_) {},
      onChat: _noop,
      onGift: _noop,
      onToggleSpeaker: _noop,
      onToggleMic: _noop,
      onEnd: _noop,
      bottomOverlay: _comments(),
    );

Widget _video(
  List<RoomParticipant> people,
  Set<int> speaking, {
  RoomPremium premium = const RoomPremium(),
  String title = 'Friday Night Hangout',
}) => VideoRoomView(
  state: _state(RoomType.video, people, title: title, premium: premium),
  myUuid: 'me',
  isSpeaking: (p) => speaking.contains(p.user.uid),
  isMuted: (p) => p.micMuted,
  videoFor: _fakeCamera,
  speakerOn: true,
  canFlipCamera: true,
  onBack: _noop,
  onFlipCamera: _noop,
  onToggleSpeaker: _noop,
  onTitle: _noop,
  onLeave: _noop,
  leaveLabel: 'Leave',
  onTapParticipant: (_) {},
  onUnlock: _noop,
  onOverflow: _noop,
  bottomOverlay: _comments(),
  tools: [
    const VideoToolItem(icon: Icons.mic_rounded, label: 'Mute', onTap: _noop),
    const VideoToolItem(
      icon: Icons.videocam_rounded,
      label: 'Stop video',
      onTap: _noop,
    ),
    const VideoToolItem(
      icon: Icons.chat_bubble_outline_rounded,
      label: 'Chat',
      onTap: _noop,
    ),
    const VideoToolItem(
      icon: Icons.card_giftcard_rounded,
      label: 'Gift',
      onTap: _noop,
    ),
    VideoToolItem(
      icon: Icons.groups_rounded,
      label: 'People',
      badge: people.length,
      onTap: _noop,
    ),
    const VideoToolItem(
      icon: Icons.workspace_premium_rounded,
      label: 'Premium',
      onTap: _noop,
    ),
  ],
);

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(child));
  // Let the sound waves get mid-swing.
  await tester.pump(const Duration(milliseconds: 260));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  testWidgets('audio room — 13 joined', (t) async {
    final people = [
      _p(0, role: 'host', muted: false),
      for (var i = 1; i < 13; i++) _p(i, muted: i != 5 && i != 9),
    ];
    await _shot(t, 'audio_room', _audio(people, {1, 6}));
  }, skip: !_enabled);

  testWidgets('video room — 10 on camera', (t) async {
    final people = [
      _p(0, role: 'host', muted: false, lady: true),
      _p(2, role: 'guest', muted: false, lady: true),
      for (final i in [1, 3, 4, 5, 6, 7, 8, 9]) _p(i, role: 'guest', muted: i.isOdd),
    ];
    await _shot(t, 'video_room_10', _video(people, {1, 3, 7}));
  }, skip: !_enabled);

  testWidgets('video room — 10 on a small phone', (t) async {
    final people = [
      _p(0, role: 'host', muted: false),
      for (final i in [2, 1, 3, 4, 5, 6, 7, 8, 9]) _p(i, role: 'guest', muted: i.isOdd),
    ];
    await _shot(
      t,
      'video_room_10_small_phone',
      _video(people, {1, 5}),
      size: const Size(320, 640),
    );
  }, skip: !_enabled);

  testWidgets('video room — 2 people', (t) async {
    final people = [
      _p(0, role: 'host', muted: false),
      _p(4, role: 'guest', muted: true),
    ];
    await _shot(t, 'video_room_2', _video(people, {1}));
  }, skip: !_enabled);

  testWidgets('video room — 5 people, premium', (t) async {
    final people = [
      _p(0, role: 'host', muted: false, lady: true, visible: false, premium: true),
      _p(2, role: 'guest', muted: false, lady: true, visible: false, premium: true),
      _p(1, role: 'guest', muted: true),
      _p(4, role: 'guest', muted: false),
      _p(7, role: 'guest', muted: true),
    ];
    await _shot(
      t,
      'video_room_5_premium',
      _video(
        people,
        {5},
        premium: const RoomPremium(enabled: true, priceCoins: 50, mode: 'host_and_ladies'),
        title: 'Ladies Night ✨',
      ),
    );
  }, skip: !_enabled);
}
