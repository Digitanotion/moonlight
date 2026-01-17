import 'package:equatable/equatable.dart';

class BlockedUser extends Equatable {
  final String id;
  final String displayName;
  final String? username;
  final String? email;
  final String? avatarUrl;
  final bool isBlocked;
  final DateTime? blockedAt;
  final int mutualConnections;
  final bool canUnblock;

  const BlockedUser({
    required this.id,
    required this.displayName,
    this.username,
    this.email,
    this.avatarUrl,
    required this.isBlocked,
    this.blockedAt,
    this.mutualConnections = 0,
    this.canUnblock = true,
  });

  @override
  List<Object?> get props => [
    id,
    displayName,
    username,
    email,
    avatarUrl,
    isBlocked,
    blockedAt,
    mutualConnections,
    canUnblock,
  ];

  BlockedUser copyWith({
    String? id,
    String? displayName,
    String? username,
    String? email,
    String? avatarUrl,
    bool? isBlocked,
    DateTime? blockedAt,
    int? mutualConnections,
    bool? canUnblock,
  }) {
    return BlockedUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedAt: blockedAt ?? this.blockedAt,
      mutualConnections: mutualConnections ?? this.mutualConnections,
      canUnblock: canUnblock ?? this.canUnblock,
    );
  }
}
