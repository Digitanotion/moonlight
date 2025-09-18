// import 'dart:async';
// import 'dart:math';

// import 'package:moonlight/features/livestream/domain/entities/live_join_request.dart';
// import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';

// class FakeLiveSessionRepository implements LiveSessionRepository {
//   final _chatCtrl = StreamController<LiveChatMessage>.broadcast();
//   final _viewersCtrl = StreamController<int>.broadcast();
//   final _requestsCtrl = StreamController<LiveJoinRequest>.broadcast();

//   Timer? _chatTimer;
//   Timer? _viewTimer;
//   Timer? _reqTimer;
//   int _viewers = 1800;

//   final _rand = Random();

//   @override
//   Stream<LiveChatMessage> chatStream() => _chatCtrl.stream;

//   @override
//   Stream<int> viewersStream() => _viewersCtrl.stream;

//   @override
//   Stream<LiveJoinRequest> joinRequestStream() => _requestsCtrl.stream;

//   @override
//   Future<void> startSession({required String topic}) async {
//     // Simulate viewers fluctuation.
//     _viewTimer?.cancel();
//     _viewTimer = Timer.periodic(const Duration(seconds: 2), (_) {
//       final delta = _rand.nextInt(7) - 3; // -3..+3
//       _viewers = (_viewers + delta).clamp(0, 999999);
//       _viewersCtrl.add(_viewers);
//     });

//     // Simulate random chat.
//     const samples = [
//       ['sarah_m', 'Great topic! 💙'],
//       ['mike_wellness', 'Thank you for sharing this'],
//       ['alex_therapy', 'Very helpful insights'],
//       ['wellness_coach', 'Love this discussion! 🌟'],
//     ];
//     _chatTimer?.cancel();
//     _chatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
//       final pick = samples[_rand.nextInt(samples.length)];
//       _chatCtrl.add(LiveChatMessage(pick[0], pick[1]));
//     });

//     // Occasional join request
//     _reqTimer?.cancel();
//     _reqTimer = Timer.periodic(const Duration(seconds: 12), (_) {
//       final id = DateTime.now().millisecondsSinceEpoch.toString();
//       _requestsCtrl.add(
//         LiveJoinRequest(
//           id: id,
//           displayName: 'GamerPro_2024',
//           role: 'Ambassador',
//           avatarUrl: 'assets/avatar_request.png',
//           online: true,
//         ),
//       );
//     });
//   }

//   @override
//   Future<void> acceptJoinRequest(String requestId) async {
//     // no-op: in real impl, call API / Agora co-stream invite accept
//   }

//   @override
//   Future<void> declineJoinRequest(String requestId) async {
//     // no-op
//   }

//   @override
//   Future<void> endSession() async {
//     _chatTimer?.cancel();
//     _viewTimer?.cancel();
//   }

//   @override
//   void dispose() {
//     _chatTimer?.cancel();
//     _viewTimer?.cancel();
//     _chatCtrl.close();
//     _viewersCtrl.close();
//     _reqTimer?.cancel();
//     _requestsCtrl.close();
//   }
// }
