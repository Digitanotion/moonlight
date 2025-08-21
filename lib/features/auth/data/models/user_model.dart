import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel extends Equatable {
  @JsonKey(name: 'id')
  final int userId;

  final String email;
  final String? name;

  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  @JsonKey(name: 'access_token')
  final String? authToken;

  @JsonKey(name: 'token_type')
  final String? tokenType;

  @JsonKey(name: 'expires_in')
  final int? expiresIn;

  const UserModel({
    required this.userId,
    required this.email,
    this.name,
    this.avatarUrl,
    this.authToken,
    this.tokenType,
    this.expiresIn,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// Model → Entity
  User toEntity() => User(
    id: userId.toString(),
    email: email,
    name: name,
    avatarUrl: avatarUrl,
    authToken: authToken,
  );

  @override
  List<Object?> get props => [userId, email, name, avatarUrl, authToken];
}

/// Entity → Model (optional helper)
extension UserEntityX on User {
  UserModel toModel() => UserModel(
    userId: int.parse(id),
    email: email,
    name: name,
    avatarUrl: avatarUrl,
    authToken: authToken,
  );
}
