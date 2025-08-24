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
  });

  String get displayName => fullname ?? agent_name ?? email;

  bool get isEmailVerified => emailVerifiedAt != null;

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
  ];
}
