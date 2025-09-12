// =============================================
// LAYER: DATA (Mock)
// =============================================

// -----------------------------
// FILE: lib/features/live/data/live_repository_mock.dart
// -----------------------------
import 'dart:async';
import 'dart:math';
import 'package:moonlight/features/livestream/domain/entities/live_entities.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_repository.dart';
import 'package:rxdart/rxdart.dart';

class LiveRepositoryMock implements LiveRepository {
  final _metaCtrl = BehaviorSubject<LiveMeta>();
  final _chatCtrl = BehaviorSubject<List<ChatMessage>>.seeded(const []);
  final _giftCtrl = BehaviorSubject<GiftEvent?>.seeded(null);
  final _guestCtrl = BehaviorSubject<GuestJoinEvent?>.seeded(null);

  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  LiveRepositoryMock() {
    // Seed meta
    _metaCtrl.add(
      LiveMeta(
        topic: 'Talking about Mental Health',
        elapsed: _elapsed,
        viewers: 247,
        isPaused: false,
      ),
    );

    // Fake ticker for elapsed + occasional banners
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      final current = _metaCtrl.value;
      _metaCtrl.add(current.copyWith(elapsed: _elapsed));

      final r = Random();
      if (r.nextInt(8) == 0) {
        _giftCtrl.add(
          GiftEvent(
            id: 'g${DateTime.now().millisecondsSinceEpoch}',
            from: 'Sarah',
            giftName: 'Golden Crown',
            coins: 500,
          ),
        );
        Future.delayed(const Duration(seconds: 4), () => _giftCtrl.add(null));
      }
      if (r.nextInt(12) == 0) {
        _guestCtrl.add(GuestJoinEvent('Jane_Star'));
        Future.delayed(const Duration(seconds: 3), () => _guestCtrl.add(null));
      }
    });

    // Seed some chat
    _chatCtrl.add([
      ChatMessage(
        id: '1',
        user: 'sarah_m',
        text: 'Great topic! 💙',
        at: DateTime.now(),
      ),
      ChatMessage(
        id: '2',
        user: 'mike_wellness',
        text: 'Thank you for sharing this',
        at: DateTime.now(),
      ),
      ChatMessage(
        id: '3',
        user: 'alex_therapy',
        text: 'Very helpful insights',
        at: DateTime.now(),
      ),
      ChatMessage(
        id: '4',
        user: 'wellness_coach',
        text: 'Love this discussion! ✨',
        at: DateTime.now(),
      ),
    ]);
  }

  @override
  Stream<LiveMeta> meta$() => _metaCtrl.stream;
  @override
  Stream<List<ChatMessage>> chat$() => _chatCtrl.stream;
  @override
  Stream<GiftEvent?> giftBanner$() => _giftCtrl.stream;
  @override
  Stream<GuestJoinEvent?> guestBanner$() => _guestCtrl.stream;

  @override
  Future<void> sendComment(String text) async {
    final list = List<ChatMessage>.from(_chatCtrl.value);
    list.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        user: 'you',
        text: text,
        at: DateTime.now(),
      ),
    );
    _chatCtrl.add(list);
  }

  @override
  Future<void> requestToJoin() async {
    // In a real impl, call API; here we just push a banner as feedback
    _guestCtrl.add(const GuestJoinEvent('You requested to join'));
    await Future.delayed(const Duration(seconds: 2));
    _guestCtrl.add(null);
  }

  @override
  Future<void> leaveStream() async {
    _metaCtrl.add(_metaCtrl.value.copyWith(isPaused: false));
  }

  // Simulate pause/resume for demo
  void togglePause() {
    _metaCtrl.add(
      _metaCtrl.value.copyWith(isPaused: !_metaCtrl.value.isPaused),
    );
  }

  void dispose() {
    _ticker?.cancel();
    _metaCtrl.close();
    _chatCtrl.close();
    _giftCtrl.close();
    _guestCtrl.close();
  }
}
