import 'package:equatable/equatable.dart';

abstract class SearchResult extends Equatable {
  final String id;
  final String name;

  const SearchResult({required this.id, required this.name});

  @override
  List<Object> get props => [id, name];
}

class UserResult extends SearchResult {
  final String username;
  final String? avatarUrl;
  final int followersCount;
  final bool isFollowing;

  const UserResult({
    required super.id,
    required super.name,
    required this.username,
    this.avatarUrl,
    this.followersCount = 0,
    this.isFollowing = false,
  });

  @override
  List<Object> get props => [
    ...super.props,
    username,
    followersCount,
    isFollowing,
  ];
}

class ClubResult extends SearchResult {
  final String description;
  final int membersCount;
  final String? coverImageUrl;
  final bool isMember;

  const ClubResult({
    required super.id,
    required super.name,
    required this.membersCount,
    this.description = '',
    this.coverImageUrl,
    this.isMember = false,
  });

  @override
  List<Object> get props => [
    ...super.props,
    description,
    membersCount,
    isMember,
  ];
}

class TagResult extends SearchResult {
  final int usageCount;

  const TagResult({
    required super.id,
    required super.name,
    this.usageCount = 0,
  });

  @override
  List<Object> get props => [...super.props, usageCount];
}
