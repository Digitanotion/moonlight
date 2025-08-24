import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';

part 'user_model.g.dart';

/// Wrapper for API response
@JsonSerializable()
class LoginResponseModel {
  final UserModel user;

  @JsonKey(name: 'access_token')
  final String? accessToken;

  @JsonKey(name: 'token_type')
  final String? tokenType;

  @JsonKey(name: 'expires_in')
  final int? expiresIn;

  LoginResponseModel({
    required this.user,
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseModelToJson(this);

  /// Convert API response into a proper UserModel with token fields
  UserModel toUserModel() {
    return user.copyWith(
      authToken: accessToken,
      tokenType: tokenType,
      expiresIn: expiresIn,
    );
  }
}

@JsonSerializable()
class UserModel extends Equatable {
  @JsonKey(name: 'id')
  final int userId;

  final String email;

  @JsonKey(name: 'agent_name')
  final String? agent_name;

  @JsonKey(name: 'user_slug')
  final String? userSlug;

  /// NEW
  @JsonKey(name: 'username')
  final String? username;

  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  @JsonKey(name: 'avatar')
  final String? avatar;

  @JsonKey(name: 'fullname')
  final String? fullname;

  final String? gender;
  final String? country;
  final String? bio;

  @JsonKey(name: 'user_interests')
  final List<String>? userInterests;

  @JsonKey(name: 'phone')
  final String? phone;

  @JsonKey(name: 'referral_code')
  final String? referralCode;

  @JsonKey(name: 'referred_by')
  final int? referredBy;

  @JsonKey(name: 'email_verified_at')
  final String? emailVerifiedAt;

  /// NEW
  @JsonKey(name: 'date_of_birth')
  final String? dateOfBirth;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  // Filled via LoginResponseModel
  final String? authToken;
  final String? tokenType;
  final int? expiresIn;

  const UserModel({
    required this.userId,
    required this.email,
    this.agent_name,
    this.userSlug,
    this.username, // NEW
    this.avatarUrl,
    this.avatar,
    this.fullname,
    this.gender,
    this.country,
    this.bio,
    this.userInterests,
    this.phone,
    this.referralCode,
    this.referredBy,
    this.emailVerifiedAt,
    this.dateOfBirth, // NEW
    this.createdAt,
    this.updatedAt,
    this.authToken,
    this.tokenType,
    this.expiresIn,
  });

  /// CopyWith to easily set token fields from response wrapper
  UserModel copyWith({
    int? userId,
    String? email,
    String? agent_name,
    String? userSlug,
    String? username, // NEW
    String? avatarUrl,
    String? avatar,
    String? fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? userInterests,
    String? phone,
    String? referralCode,
    int? referredBy,
    String? emailVerifiedAt,
    String? dateOfBirth, // NEW
    String? createdAt,
    String? updatedAt,
    String? authToken,
    String? tokenType,
    int? expiresIn,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      agent_name: agent_name ?? this.agent_name,
      userSlug: userSlug ?? this.userSlug,
      username: username ?? this.username, // NEW
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatar: avatar ?? this.avatar,
      fullname: fullname ?? this.fullname,
      gender: gender ?? this.gender,
      country: country ?? this.country,
      bio: bio ?? this.bio,
      userInterests: userInterests ?? this.userInterests,
      phone: phone ?? this.phone,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth, // NEW
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authToken: authToken ?? this.authToken,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
  // NEW: map UserResource (shape returned by /v1/me -> { data: {...} } but we pass just the map)
  /// NEW: map UserResource (shape returned by /v1/me and /v1/users/{slug})
  /// NOTE: we pass the inner `{...}` map (not the envelope { "data": {...} }).
  factory UserModel.fromUserResource(Map<String, dynamic> json) => UserModel(
    userId: (json['id'] as num).toInt(),
    email: (json['email'] as String?) ?? '', // spec includes email
    userSlug: json['user_slug'] as String?,
    username: json['username'] as String?,
    fullname: json['fullname'] as String?,
    bio: json['bio'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    gender: json['gender'] as String?,
    country: json['country'] as String?, // may be country code e.g. "NG"
    dateOfBirth: json['date_of_birth'] as String?,
    userInterests: (json['user_interests'] as List?)
        ?.map((e) => e.toString())
        .toList(),
    // Optional / not guaranteed in UserResource:
    phone: json['phone'] as String?,
    agent_name: json['agent_name'] as String?,
    referralCode: json['referral_code'] as String?,
    referredBy: (json['referred_by'] as num?)?.toInt(),
    emailVerifiedAt: json['email_verified_at'] as String?,
    createdAt: json['created_at'] as String?,
    updatedAt: json['updated_at'] as String?,
    // Auth fields are not in /v1/me; keep null
    authToken: null,
    tokenType: null,
    expiresIn: null,
    // 'avatar' raw not present in UserResource; keep null
    avatar: null,
  );

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// Model → Entity
  User toEntity() => User(
    id: userId.toString(),
    email: email,
    agent_name: agent_name,
    userSlug: userSlug,
    avatarUrl: avatarUrl ?? avatar,
    fullname: fullname,
    gender: gender,
    country: country,
    bio: bio,
    userInterests: userInterests,
    phone: phone,
    referralCode: referralCode,
    referredBy: referredBy?.toString(),
    emailVerifiedAt: emailVerifiedAt,
    authToken: authToken,
  );

  /// Get display name (prefer fullname if available)
  String get displayName => fullname ?? agent_name ?? email;

  /// Check if email is verified
  bool get isEmailVerified => emailVerifiedAt != null;

  @override
  List<Object?> get props => [
    userId,
    email,
    agent_name,
    userSlug,
    username, // NEW
    avatarUrl,
    avatar,
    fullname,
    gender,
    country,
    bio,
    userInterests,
    phone,
    referralCode,
    referredBy,
    emailVerifiedAt,
    dateOfBirth, // NEW
    createdAt,
    updatedAt,
    authToken,
    tokenType,
    expiresIn,
  ];
}

/// Entity → Model (optional helper)
extension UserEntityX on User {
  UserModel toModel() => UserModel(
    userId: int.parse(id),
    email: email,
    agent_name: agent_name,
    userSlug: userSlug,
    avatarUrl: avatarUrl,
    avatar: avatarUrl, // Map entity avatarUrl to both avatar and avatarUrl
    fullname: fullname,
    gender: gender,
    country: country,
    bio: bio,
    userInterests: userInterests,
    phone: phone,
    referralCode: referralCode,
    referredBy: referredBy != null ? int.parse(referredBy!) : null,
    emailVerifiedAt: emailVerifiedAt,
    authToken: authToken,
  );
}
