import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String? agent_name;
  final String? userSlug;
  final String? avatarUrl;
  final String? fullname;
  final String? gender;
  final String? country;
  final String? bio;
  final List<String>? userInterests;
  final String? phone;
  final String? referralCode;
  final String? referredBy;
  final String? emailVerifiedAt;
  final String? authToken;
  final bool? isVideoCallOnline;
  final bool? videoCallEnabled;

  const User({
    required this.id,
    required this.email,
    this.agent_name,
    this.userSlug,
    this.avatarUrl,
    this.fullname,
    this.gender,
    this.country,
    this.bio,
    this.userInterests,
    this.phone,
    this.referralCode,
    this.referredBy,
    this.emailVerifiedAt,
    this.authToken,
    this.isVideoCallOnline,
    this.videoCallEnabled,
  });

  String get displayName => fullname ?? agent_name ?? email;

  bool get isEmailVerified => emailVerifiedAt != null;

  User copyWith({
    String? id,
    String? email,
    String? agent_name,
    String? userSlug,
    String? avatarUrl,
    String? fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? userInterests,
    String? phone,
    String? referralCode,
    String? referredBy,
    String? emailVerifiedAt,
    String? authToken,
    bool? isVideoCallOnline,
    bool? videoCallEnabled,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      agent_name: agent_name ?? this.agent_name,
      userSlug: userSlug ?? this.userSlug,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fullname: fullname ?? this.fullname,
      gender: gender ?? this.gender,
      country: country ?? this.country,
      bio: bio ?? this.bio,
      userInterests: userInterests ?? this.userInterests,
      phone: phone ?? this.phone,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      authToken: authToken ?? this.authToken,
      isVideoCallOnline: isVideoCallOnline ?? this.isVideoCallOnline,
      videoCallEnabled: videoCallEnabled ?? this.videoCallEnabled,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    agent_name,
    userSlug,
    avatarUrl,
    fullname,
    gender,
    country,
    bio,
    userInterests,
    phone,
    referralCode,
    referredBy,
    emailVerifiedAt,
    authToken,
    isVideoCallOnline,
    videoCallEnabled,
  ];
}