import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';

part 'user_model.g.dart';

/// Wrapper for API login response (no UUID here; only token + minimal user)
@JsonSerializable()
class LoginResponseModel {
  final UserModel user;

  @JsonKey(name: 'access_token')
  final String? accessToken;

  @JsonKey(name: 'token_type')
  final String? tokenType;

  @JsonKey(name: 'expires_in')
  final String? expiresIn;

  LoginResponseModel({
    required this.user,
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseModelToJson(this);

  /// Convert API response into a proper UserModel with token fields.
  /// NOTE: This does NOT inject UUID (login payload usually has no uuid).
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
  /// New: UUID exposed by the API everywhere (this is what we persist & expose).
  @JsonKey(name: 'uuid')
  final String? uuid;

  /// Legacy: some endpoints still return numeric id (keep for compatibility).
  @JsonKey(name: 'id')
  final String? userId;

  final String email;

  @JsonKey(name: 'agent_name')
  final String? agent_name;

  @JsonKey(name: 'user_slug')
  final String? userSlug;

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

  @JsonKey(name: 'roleLabel')
  final String? roleLabel;

  @JsonKey(name: 'referral_code')
  final String? referralCode;

  @JsonKey(name: 'referred_by')
  final String? referredBy;

  @JsonKey(name: 'email_verified_at')
  final String? emailVerifiedAt;

  @JsonKey(name: 'date_of_birth')
  final String? dateOfBirth;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  // Filled via LoginResponseModel
  final String? authToken;
  final String? tokenType;
  final String? expiresIn;

  const UserModel({
    this.uuid,
    this.userId,
    required this.email,
    this.agent_name,
    this.userSlug,
    this.username,
    this.avatarUrl,
    this.avatar,
    this.fullname,
    this.gender,
    this.country,
    this.bio,
    this.userInterests,
    this.phone,
    this.roleLabel,
    this.referralCode,
    this.referredBy,
    this.emailVerifiedAt,
    this.dateOfBirth,
    this.createdAt,
    this.updatedAt,
    this.authToken,
    this.tokenType,
    this.expiresIn,
  });

  /// CopyWith (keeps immutability)
  UserModel copyWith({
    String? uuid,
    String? userId,
    String? email,
    String? agent_name,
    String? userSlug,
    String? username,
    String? avatarUrl,
    String? avatar,
    String? fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? userInterests,
    String? phone,
    String? referralCode,
    String? referredBy,
    String? emailVerifiedAt,
    String? dateOfBirth,
    String? createdAt,
    String? updatedAt,
    String? authToken,
    String? tokenType,
    String? expiresIn,
  }) {
    return UserModel(
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      agent_name: agent_name ?? this.agent_name,
      userSlug: userSlug ?? this.userSlug,
      username: username ?? this.username,
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
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authToken: authToken ?? this.authToken,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Map **UserResource** (the `data` from `/v1/me`) — this includes `uuid`.
  /// NOTE: we pass the inner `{...}` map (not the envelope `{ "data": {...} }`).
  factory UserModel.fromUserResource(Map<String, dynamic> json) => UserModel(
    uuid: json['uuid'] as String?,
    userId: json['id'],
    email: (json['email'] as String?) ?? '',
    userSlug: json['user_slug'] as String?,
    username: json['username'] as String?,
    fullname: json['fullname'] as String?,
    bio: json['bio'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    gender: json['gender'] as String?,
    country: json['country'] as String?,
    dateOfBirth: json['date_of_birth'] as String?,
    userInterests: (json['user_interests'] as List?)?.map((e) => '$e').toList(),
    // Optional / not guaranteed in UserResource:
    phone: json['phone'] as String?,
    agent_name: json['agent_name'] as String?,
    referralCode: json['referral_code'] as String?,
    referredBy: json['referred_by'] as String?,
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
  /// IMPORTANT: We expose **uuid** in the entity's `id` field (so old code using `user.id` keeps working).
  User toEntity() => User(
    id: (uuid ?? userId?.toString() ?? ''),
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

  /// Display helpers
  String get displayName => fullname ?? agent_name ?? email;
  bool get isEmailVerified => emailVerifiedAt != null;

  @override
  List<Object?> get props => [
    uuid,
    userId,
    email,
    agent_name,
    userSlug,
    username,
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
    dateOfBirth,
    createdAt,
    updatedAt,
    authToken,
    tokenType,
    expiresIn,
  ];
}

/// Entity → Model (helper for caching etc.)
extension UserEntityX on User {
  UserModel toModel() => UserModel(
    uuid: id, // our entity.id is UUID now
    userId: "", // we no longer rely on numeric ids
    email: email,
    agent_name: agent_name,
    userSlug: userSlug,
    avatarUrl: avatarUrl,
    avatar: avatarUrl,
    fullname: fullname,
    gender: gender,
    country: country,
    bio: bio,
    userInterests: userInterests,
    phone: phone,
    referralCode: referralCode,
    referredBy: referredBy,
    emailVerifiedAt: emailVerifiedAt,
    authToken: authToken,
  );
}
