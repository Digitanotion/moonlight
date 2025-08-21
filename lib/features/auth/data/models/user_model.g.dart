// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  userId: json['id'] as int,
  email: json['email'] as String,
  name: json['name'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  authToken: json['authToken'] as String?,
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.userId,
  'email': instance.email,
  'name': instance.name,
  'avatarUrl': instance.avatarUrl,
  'authToken': instance.authToken,
};
