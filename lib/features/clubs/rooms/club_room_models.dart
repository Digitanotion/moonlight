// lib/features/clubs/rooms/club_room_models.dart
//
// Shapes returned by the club room API (ClubRoomService::state & friends).

enum RoomType { audio, video }

RoomType _type(Object? v) => v == 'audio' ? RoomType.audio : RoomType.video;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

class RoomUser {
  final String uuid;
  final int uid; // Agora uid
  final String display;
  final String? avatarUrl;
  final bool isLady;
  final bool isHost;
  final bool isOwner;

  const RoomUser({
    required this.uuid,
    required this.uid,
    required this.display,
    this.avatarUrl,
    this.isLady = false,
    this.isHost = false,
    this.isOwner = false,
  });

  factory RoomUser.fromJson(Map<String, dynamic> j) => RoomUser(
    uuid: j['uuid']?.toString() ?? '',
    uid: _int(j['uid']),
    display: j['display']?.toString() ?? 'Member',
    avatarUrl: j['avatar_url']?.toString(),
    isLady: j['is_lady'] == true,
    isHost: j['is_host'] == true,
    isOwner: j['is_owner'] == true,
  );
}

class RoomParticipant {
  final RoomUser user;
  final String role; // host | guest | speaker | viewer
  final bool micMuted;
  final String? seatRequest;
  final bool videoPremium;
  final bool videoVisible;

  const RoomParticipant({
    required this.user,
    required this.role,
    required this.micMuted,
    this.seatRequest,
    this.videoPremium = false,
    this.videoVisible = true,
  });

  bool get onStage => role == 'host' || role == 'guest' || role == 'speaker';

  factory RoomParticipant.fromJson(Map<String, dynamic> j) => RoomParticipant(
    user: RoomUser.fromJson(j),
    role: j['role']?.toString() ?? 'viewer',
    micMuted: j['mic_muted'] == true,
    seatRequest: j['seat_request']?.toString(),
    videoPremium: j['video_premium'] == true,
    videoVisible: j['video_visible'] != false,
  );
}

class RoomMe {
  final bool inRoom;
  final bool removed;
  final String? role;
  final bool micMuted;
  final String? seatRequest;
  final bool canModerate;
  final bool isOwner;
  final int seatFeeCoins;
  final int joinFeeCoins;
  final bool premiumAccess;

  const RoomMe({
    this.inRoom = false,
    this.removed = false,
    this.role,
    this.micMuted = false,
    this.seatRequest,
    this.canModerate = false,
    this.isOwner = false,
    this.seatFeeCoins = 0,
    this.joinFeeCoins = 0,
    this.premiumAccess = true,
  });

  bool get onStage => role == 'host' || role == 'guest' || role == 'speaker';
  bool get isHost => role == 'host';

  factory RoomMe.fromJson(Map<String, dynamic> j) => RoomMe(
    inRoom: j['in_room'] == true,
    removed: j['removed'] == true,
    role: j['role']?.toString(),
    micMuted: j['mic_muted'] == true,
    seatRequest: j['seat_request']?.toString(),
    canModerate: j['can_moderate'] == true,
    isOwner: j['is_owner'] == true,
    seatFeeCoins: _int(j['seat_fee_coins']),
    joinFeeCoins: _int(j['join_fee_coins']),
    premiumAccess: j['premium_access'] != false,
  );
}

class RoomPremium {
  final bool enabled;
  final int priceCoins;
  final String? mode; // host_only | host_and_ladies

  const RoomPremium({this.enabled = false, this.priceCoins = 0, this.mode});

  factory RoomPremium.fromJson(Map<String, dynamic>? j) => RoomPremium(
    enabled: j?['enabled'] == true,
    priceCoins: _int(j?['price_coins']),
    mode: j?['mode']?.toString(),
  );
}

class RoomState {
  final String uuid;
  final RoomType type;
  final String status;
  final String? title;
  final String clubUuid;
  final String clubName;
  final RoomUser host;
  final int capacity;
  final int freeSlots;
  final int freeSlotsLeft;
  final int entryFeeCoins;
  final RoomPremium premium;
  final DateTime? startedAt;
  final List<RoomParticipant> participants;
  final List<RoomUser> seatRequests;
  final RoomMe me;

  const RoomState({
    required this.uuid,
    required this.type,
    required this.status,
    this.title,
    required this.clubUuid,
    required this.clubName,
    required this.host,
    required this.capacity,
    required this.freeSlots,
    required this.freeSlotsLeft,
    required this.entryFeeCoins,
    required this.premium,
    this.startedAt,
    required this.participants,
    required this.seatRequests,
    required this.me,
  });

  bool get isAudio => type == RoomType.audio;
  bool get isLive => status == 'live';
  List<RoomParticipant> get onStage =>
      participants.where((p) => p.onStage).toList();
  List<RoomParticipant> get viewers =>
      participants.where((p) => !p.onStage).toList();

  factory RoomState.fromJson(Map<String, dynamic> j) {
    final club = Map<String, dynamic>.from((j['club'] as Map?) ?? const {});
    return RoomState(
      uuid: j['uuid']?.toString() ?? '',
      type: _type(j['type']),
      status: j['status']?.toString() ?? 'ended',
      title: j['title']?.toString(),
      clubUuid: club['uuid']?.toString() ?? '',
      clubName: club['name']?.toString() ?? 'Club',
      host: RoomUser.fromJson(
        Map<String, dynamic>.from((j['host'] as Map?) ?? const {}),
      ),
      capacity: _int(j['capacity']),
      freeSlots: _int(j['free_slots']),
      freeSlotsLeft: _int(j['free_slots_left']),
      entryFeeCoins: _int(j['entry_fee_coins']),
      premium: RoomPremium.fromJson(
        (j['premium'] as Map?)?.cast<String, dynamic>(),
      ),
      startedAt: DateTime.tryParse(j['started_at']?.toString() ?? ''),
      participants: ((j['participants'] as List?) ?? const [])
          .map((e) => RoomParticipant.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      seatRequests: ((j['seat_requests'] as List?) ?? const [])
          .map((e) => RoomUser.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      me: RoomMe.fromJson(
        Map<String, dynamic>.from((j['me'] as Map?) ?? const {}),
      ),
    );
  }
}

class LiveRoomSummary {
  final String uuid;
  final RoomType type;
  final String? title;
  final RoomUser host;
  final int presentCount;
  final bool isPremium;

  const LiveRoomSummary({
    required this.uuid,
    required this.type,
    this.title,
    required this.host,
    required this.presentCount,
    required this.isPremium,
  });

  factory LiveRoomSummary.fromJson(Map<String, dynamic> j) => LiveRoomSummary(
    uuid: j['uuid']?.toString() ?? '',
    type: _type(j['type']),
    title: j['title']?.toString(),
    host: RoomUser.fromJson(
      Map<String, dynamic>.from((j['host'] as Map?) ?? const {}),
    ),
    presentCount: _int(j['present_count']),
    isPremium: j['is_premium'] == true,
  );
}

class RtcCredentials {
  final String appId;
  final String channel;
  final int uid;
  final String role; // publisher | subscriber
  final String token;

  const RtcCredentials({
    required this.appId,
    required this.channel,
    required this.uid,
    required this.role,
    required this.token,
  });

  bool get isPublisher => role == 'publisher';

  factory RtcCredentials.fromJson(Map<String, dynamic> j) => RtcCredentials(
    appId: j['app_id']?.toString() ?? '',
    channel: j['channel']?.toString() ?? '',
    uid: _int(j['uid']),
    role: j['role']?.toString() ?? 'subscriber',
    token: j['token']?.toString() ?? '',
  );
}

class RoomComment {
  final String uuid;
  final String? body;
  final String? mediaUrl;
  final String? mediaType; // image | video
  final bool edited;
  final DateTime? createdAt;
  final RoomUser? user;
  final String? replyToUuid;
  final String? replyToBody;
  final String? replyToUser;
  final bool replyToDeleted;

  const RoomComment({
    required this.uuid,
    this.body,
    this.mediaUrl,
    this.mediaType,
    this.edited = false,
    this.createdAt,
    this.user,
    this.replyToUuid,
    this.replyToBody,
    this.replyToUser,
    this.replyToDeleted = false,
  });

  factory RoomComment.fromJson(Map<String, dynamic> j) {
    final reply = (j['reply_to'] as Map?)?.cast<String, dynamic>();
    final user = (j['user'] as Map?)?.cast<String, dynamic>();
    return RoomComment(
      uuid: j['uuid']?.toString() ?? '',
      body: j['body']?.toString(),
      mediaUrl: j['media_url']?.toString(),
      mediaType: j['media_type']?.toString(),
      edited: j['edited'] == true,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
      user: user == null ? null : RoomUser.fromJson(user),
      replyToUuid: reply?['uuid']?.toString(),
      replyToBody: reply?['body']?.toString(),
      replyToUser: reply?['user']?.toString(),
      replyToDeleted: reply?['deleted'] == true,
    );
  }
}
