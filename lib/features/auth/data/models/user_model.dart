import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final String? authToken;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.authToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// Model → Entity
  User toEntity() => User(
    id: id,
    email: email,
    name: name,
    avatarUrl: avatarUrl,
    authToken: authToken,
  );

  @override
  List<Object?> get props => [id, email, name, avatarUrl];
}

/// Entity → Model (optional helper)
extension UserEntityX on User {
  UserModel toModel() => UserModel(
    id: id,
    email: email,
    name: name,
    avatarUrl: avatarUrl,
    authToken: authToken,
  );
}
