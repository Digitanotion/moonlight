// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginResponseModel _$LoginResponseModelFromJson(Map<String, dynamic> json) =>
    LoginResponseModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['access_token'] as String?,
      tokenType: json['token_type'] as String?,
      expiresIn: json['expires_in'] as String?,
    );

Map<String, dynamic> _$LoginResponseModelToJson(LoginResponseModel instance) =>
    <String, dynamic>{
      'user': instance.user,
      'access_token': instance.accessToken,
      'token_type': instance.tokenType,
      'expires_in': instance.expiresIn,
    };

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  uuid: json['uuid'] as String?,
  userId: json['id'] as String?,
  email: json['email'] as String,
  agent_name: json['agent_name'] as String?,
  userSlug: json['user_slug'] as String?,
  username: json['username'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  avatar: json['avatar'] as String?,
  fullname: json['fullname'] as String?,
  gender: json['gender'] as String?,
  country: json['country'] as String?,
  bio: json['bio'] as String?,
  userInterests: (json['user_interests'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  phone: json['phone'] as String?,
  roleLabel: json['roleLabel'] as String?,
  referralCode: json['referral_code'] as String?,
  referredBy: json['referred_by'] as String?,
  emailVerifiedAt: json['email_verified_at'] as String?,
  dateOfBirth: json['date_of_birth'] as String?,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  authToken: json['access_token'] as String?, // ✅ THIS LINE IS CRITICAL
  tokenType: json['token_type'] as String?, // ✅ THIS LINE IS CRITICAL
  expiresIn: json['expires_in'] as String?, // ✅ THIS LINE IS CRITICAL
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'id': instance.userId,
  'email': instance.email,
  'agent_name': instance.agent_name,
  'user_slug': instance.userSlug,
  'username': instance.username,
  'avatar_url': instance.avatarUrl,
  'avatar': instance.avatar,
  'fullname': instance.fullname,
  'gender': instance.gender,
  'country': instance.country,
  'bio': instance.bio,
  'user_interests': instance.userInterests,
  'phone': instance.phone,
  'roleLabel': instance.roleLabel,
  'referral_code': instance.referralCode,
  'referred_by': instance.referredBy,
  'email_verified_at': instance.emailVerifiedAt,
  'date_of_birth': instance.dateOfBirth,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'access_token': instance.authToken, // ✅ THIS LINE IS CRITICAL
  'token_type': instance.tokenType, // ✅ THIS LINE IS CRITICAL
  'expires_in': instance.expiresIn, // ✅ THIS LINE IS CRITICAL
};
