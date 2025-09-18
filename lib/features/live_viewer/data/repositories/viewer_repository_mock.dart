// import 'dart:async';
// import 'dart:math';
// import '../../domain/entities.dart';
// import '../../domain/repositories/viewer_repository.dart';

// class ViewerRepositoryMock implements ViewerRepository {
//   final _clockCtrl = StreamController<Duration>.broadcast();
//   final _viewerCtrl = StreamController<int>.broadcast();
//   final _chatCtrl = StreamController<ChatMessage>.broadcast();
//   final _guestCtrl = StreamController<GuestJoinNotice>.broadcast();
//   final _giftCtrl = StreamController<GiftNotice>.broadcast();
//   final _pauseCtrl = StreamController<bool>.broadcast();
//   final _endedCtrl = StreamController<void>.broadcast();

//   Timer? _clockTimer;
//   Timer? _viewerTimer;
//   Timer? _chatTimer;

//   int _likes = 23500; // 23.5k
//   int _shares = 0;

//   @override
//   Future<HostInfo> fetchHostInfo() async {
//     await Future.delayed(const Duration(milliseconds: 250));
//     return const HostInfo(
//       name: 'Emma watson',
//       title: 'Talking about Mental Health',
//       subtitle: 'Mental health Coach. 1.2M Fans',
//       badge: 'Superstar',
//       avatarUrl:
//           'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?auto=compress&w=120',
//       isFollowed: false,
//     );
//   }

//   @override
//   Stream<Duration> watchLiveClock() {
//     var elapsed = Duration.zero;
//     _clockTimer?.cancel();
//     _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       elapsed += const Duration(seconds: 1);
//       _clockCtrl.add(elapsed);
//     });
//     return _clockCtrl.stream;
//   }

//   @override
//   Stream<int> watchViewerCount() {
//     var count = 247;
//     final rnd = Random();
//     _viewerTimer?.cancel();
//     _viewerTimer = Timer.periodic(const Duration(seconds: 2), (_) {
//       count += rnd.nextInt(3) - 1; // wiggle
//       if (count < 200) count = 200;
//       _viewerCtrl.add(count);
//     });
//     return _viewerCtrl.stream;
//   }

//   @override
//   Stream<ChatMessage> watchChat() {
//     final samples = <ChatMessage>[
//       const ChatMessage(id: '1', username: 'sarah_m', text: 'Great topic! 💙'),
//       const ChatMessage(
//         id: '2',
//         username: 'mike_wellness',
//         text: 'Thank you for sharing this',
//       ),
//       const ChatMessage(
//         id: '3',
//         username: 'alex_therapy',
//         text: 'Very helpful insights',
//       ),
//       const ChatMessage(
//         id: '4',
//         username: 'wellness_coach',
//         text: 'Love this discussion! ✨',
//       ),
//     ];
//     var i = 0;
//     _chatTimer?.cancel();
//     _chatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
//       _chatCtrl.add(samples[i % samples.length]);
//       i++;
//     });

//     // schedule demo banners
//     Future.delayed(const Duration(seconds: 2), () {
//       _guestCtrl.add(
//         const GuestJoinNotice(
//           username: 'Jane_Star',
//           message: 'has joined the stream as a guest!',
//         ),
//       );
//     });
//     Future.delayed(const Duration(seconds: 5), () {
//       _giftCtrl.add(
//         const GiftNotice(from: 'Sarah', giftName: 'Golden Crown', coins: 500),
//       );
//     });

//     return _chatCtrl.stream;
//   }

//   @override
//   Stream<GuestJoinNotice> watchGuestJoins() => _guestCtrl.stream;

//   @override
//   Stream<GiftNotice> watchGifts() => _giftCtrl.stream;

//   @override
//   Future<void> sendComment(String text) async {
//     _chatCtrl.add(
//       ChatMessage(
//         id: DateTime.now().millisecondsSinceEpoch.toString(),
//         username: 'you',
//         text: text,
//       ),
//     );
//   }

//   @override
//   Future<int> like() async => ++_likes;

//   @override
//   Future<int> share() async => ++_shares;

//   @override
//   Future<void> requestToJoin() async {}

//   @override
//   Future<bool> toggleFollow(bool follow) async => !follow;

//   @override
//   Stream<bool> watchPause() {
//     // Demo: pause at 8s, resume at 16s (delete when wiring real API)
//     Future.delayed(const Duration(seconds: 8), () => _pauseCtrl.add(true));
//     Future.delayed(const Duration(seconds: 16), () => _pauseCtrl.add(false));
//     return _pauseCtrl.stream;
//   }

//   @override
//   Stream<void> watchEnded() {
//     // mock never ends by default
//     return _endedCtrl.stream;
//   }

//   @override
//   void dispose() {
//     _clockTimer?.cancel();
//     _viewerTimer?.cancel();
//     _chatTimer?.cancel();
//     _clockCtrl.close();
//     _viewerCtrl.close();
//     _chatCtrl.close();
//     _guestCtrl.close();
//     _giftCtrl.close();
//     _pauseCtrl.close();
//     _endedCtrl.close();
//   }
// }
