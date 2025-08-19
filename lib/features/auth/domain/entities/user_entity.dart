import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final String? authToken;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.authToken,
  });

  @override
  List<Object?> get props => [id, email, name, avatarUrl];
}
