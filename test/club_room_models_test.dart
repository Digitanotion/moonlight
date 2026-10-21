import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/clubs/rooms/club_room_models.dart';

// Shape of ClubRoomService::state() / commentPayload() on the API.
const _state = {
  'uuid': 'r1',
  'type': 'video',
  'status': 'live',
  'title': 'Friday hangout',
  'club': {'uuid': 'c1', 'name': 'Lagos Lovers', 'owner_uuid': 'u-owner'},
  'host': {
    'uuid': 'u-host',
    'uid': 7,
    'display': 'Ada',
    'avatar_url': null,
    'is_lady': true,
    'is_host': true,
    'is_owner': false,
  },
  'capacity': 10,
  'free_slots': 0,
  'free_slots_left': 0,
  'entry_fee_coins': 20,
  'premium': {'enabled': true, 'price_coins': 50, 'mode': 'host_and_ladies'},
  'present_count': 3,
  'participants': [
    {
      'uuid': 'u-host',
      'uid': 7,
      'display': 'Ada',
      'is_lady': true,
      'is_host': true,
      'role': 'host',
      'mic_muted': false,
      'video_premium': true,
      'video_visible': false,
    },
    {
      'uuid': 'u-guest',
      'uid': 9,
      'display': 'Bola',
      'role': 'guest',
      'mic_muted': true,
      'video_premium': false,
      'video_visible': true,
    },
    {
      'uuid': 'u-me',
      'uid': 11,
      'display': 'Me',
      'role': 'viewer',
      'mic_muted': false,
      'seat_request': 'pending',
    },
  ],
  'seat_requests': [],
  'me': {
    'in_room': true,
    'removed': false,
    'role': 'viewer',
    'mic_muted': false,
    'seat_request': 'pending',
    'can_moderate': false,
    'is_owner': false,
    'seat_fee_coins': 0,
    'join_fee_coins': 0,
    'premium_access': false,
  },
};

void main() {
  test('RoomState parses a video room with premium', () {
    final s = RoomState.fromJson(Map<String, dynamic>.from(_state));

    expect(s.type, RoomType.video);
    expect(s.isLive, isTrue);
    expect(s.clubName, 'Lagos Lovers');
    expect(s.host.isLady, isTrue);
    expect(s.premium.enabled, isTrue);
    expect(s.premium.priceCoins, 50);
    expect(s.premium.mode, 'host_and_ladies');

    expect(s.onStage.map((p) => p.user.uuid), ['u-host', 'u-guest']);
    expect(s.viewers.single.user.uid, 11);
    expect(s.participants.first.videoVisible, isFalse);
    expect(s.participants[1].micMuted, isTrue);

    expect(s.me.inRoom, isTrue);
    expect(s.me.onStage, isFalse);
    expect(s.me.seatRequest, 'pending');
    expect(s.me.premiumAccess, isFalse);
  });

  test('RoomComment parses a reply with media and a deleted parent', () {
    final c = RoomComment.fromJson({
      'uuid': 'cm2',
      'body': null,
      'media_url': 'https://x/clip.mp4',
      'media_type': 'video',
      'edited': true,
      'created_at': '2026-10-18T10:00:00Z',
      'user': {'uuid': 'u1', 'uid': 1, 'display': 'Ada'},
      'reply_to': {
        'uuid': 'cm1',
        'body': null,
        'deleted': true,
        'user': 'Bola',
      },
    });

    expect(c.mediaType, 'video');
    expect(c.edited, isTrue);
    expect(c.user!.display, 'Ada');
    expect(c.replyToUuid, 'cm1');
    expect(c.replyToDeleted, isTrue);
    expect(c.createdAt, DateTime.utc(2026, 10, 18, 10));
  });

  test('RtcCredentials knows publisher vs subscriber', () {
    final pub = RtcCredentials.fromJson({
      'app_id': 'a',
      'channel': 'club_video_x',
      'uid': 5,
      'role': 'publisher',
      'token': 't',
    });
    expect(pub.isPublisher, isTrue);
    expect(
      RtcCredentials.fromJson({'role': 'subscriber'}).isPublisher,
      isFalse,
    );
  });
}
