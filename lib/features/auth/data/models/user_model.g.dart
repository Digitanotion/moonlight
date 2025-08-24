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
      expiresIn: (json['expires_in'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LoginResponseModelToJson(LoginResponseModel instance) =>
    <String, dynamic>{
      'user': instance.user,
      'access_token': instance.accessToken,
      'token_type': instance.tokenType,
      'expires_in': instance.expiresIn,
    };

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  userId: (json['id'] as num).toInt(),
  email: json['email'] as String,
  agent_name: json['agent_name'] as String?,
  userSlug: json['user_slug'] as String?,
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
  referralCode: json['referral_code'] as String?,
  referredBy: (json['referred_by'] as num?)?.toInt(),
  emailVerifiedAt: json['email_verified_at'] as String?,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  authToken: json['authToken'] as String?,
  tokenType: json['tokenType'] as String?,
  expiresIn: (json['expiresIn'] as num?)?.toInt(),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.userId,
  'email': instance.email,
  'agent_name': instance.agent_name,
  'user_slug': instance.userSlug,
  'avatar_url': instance.avatarUrl,
  'avatar': instance.avatar,
  'fullname': instance.fullname,
  'gender': instance.gender,
  'country': instance.country,
  'bio': instance.bio,
  'user_interests': instance.userInterests,
  'phone': instance.phone,
  'referral_code': instance.referralCode,
  'referred_by': instance.referredBy,
  'email_verified_at': instance.emailVerifiedAt,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'authToken': instance.authToken,
  'tokenType': instance.tokenType,
  'expiresIn': instance.expiresIn,
};
