// In club.dart
import 'package:equatable/equatable.dart';

/// A live audio / video room in a club (from the club list API).
class ClubLiveRoom extends Equatable {
  final String uuid;
  final bool isVideo;
  final String? title;
  final int presentCount;

  const ClubLiveRoom({
    required this.uuid,
    required this.isVideo,
    this.title,
    this.presentCount = 0,
  });

  factory ClubLiveRoom.fromJson(Map<String, dynamic> j) => ClubLiveRoom(
    uuid: j['uuid']?.toString() ?? '',
    isVideo: j['type']?.toString() == 'video',
    title: j['title']?.toString(),
    presentCount: (j['present_count'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [uuid, isVideo, title, presentCount];
}

class Club extends Equatable {
  final String uuid;
  final String slug;
  final String name;
  final String? description;
  final int membersCount;
  final String? coverImageUrl;
  final bool isCreator;
  final bool isAdmin;
  final bool isPrivate;
  final bool isMember;

  /// Rooms live right now (audio and/or video).
  final List<ClubLiveRoom> liveRooms;

  Club({
    required this.uuid,
    required this.slug,
    required this.name,
    this.description,
    required this.membersCount,
    this.coverImageUrl,
    required this.isCreator,
    required this.isAdmin,
    required this.isPrivate,
    required this.isMember,
    this.liveRooms = const [],
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      uuid: json['uuid']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),

      membersCount:
          (json['membersCount'] as num?)?.toInt() ??
          (json['members_count'] as num?)?.toInt() ??
          0,

      coverImageUrl:
          json['avatar_url']?.toString() ?? json['coverImageUrl']?.toString(),

      // ✅ admin object OR explicit isCreator flag
      isCreator: json['isCreator'] ?? false,
      isAdmin: json['isAdmin'] ?? false,

      isPrivate: json['isPrivate'] ?? false,

      isMember: json['isMember'] ?? false,

      liveRooms: ((json['liveRooms'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ClubLiveRoom.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  // Add copyWith method
  Club copyWith({
    String? uuid,
    String? slug,
    String? name,
    String? description,
    int? membersCount,
    String? coverImageUrl,
    bool? isCreator,
    bool? isAdmin,
    bool? isPrivate,
    bool? isMember,
    List<ClubLiveRoom>? liveRooms,
  }) {
    return Club(
      uuid: uuid ?? this.uuid,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      membersCount: membersCount ?? this.membersCount,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      isCreator: isCreator ?? this.isCreator,
      isAdmin: isAdmin ?? this.isAdmin,

      isPrivate: isPrivate ?? this.isPrivate,
      isMember: isMember ?? this.isMember,
      liveRooms: liveRooms ?? this.liveRooms,
    );
  }

  @override
  List<Object?> get props => [
    uuid,
    slug,
    name,
    description,
    membersCount,
    coverImageUrl,
    isCreator,
    isAdmin,
    isPrivate,
    isMember,
    liveRooms,
  ];
}
