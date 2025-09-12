// -----------------------------
// FILE: lib/features/live/domain/entities/live_entities.dart
// -----------------------------
import 'package:equatable/equatable.dart';

class LiveHost extends Equatable {
  final String id;
  final String name;
  final String handle;
  final String roleBadge; // Diamond / Superstar labels
  final bool verified;
  final int followers;
  final String avatarUrl;

  const LiveHost({
    required this.id,
    required this.name,
    required this.handle,
    required this.roleBadge,
    required this.verified,
    required this.followers,
    required this.avatarUrl,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    handle,
    roleBadge,
    verified,
    followers,
    avatarUrl,
  ];
}

class LiveMeta extends Equatable {
  final String topic;
  final Duration elapsed;
  final int viewers;
  final bool isPaused;

  const LiveMeta({
    required this.topic,
    required this.elapsed,
    required this.viewers,
    required this.isPaused,
  });

  LiveMeta copyWith({
    String? topic,
    Duration? elapsed,
    int? viewers,
    bool? isPaused,
  }) => LiveMeta(
    topic: topic ?? this.topic,
    elapsed: elapsed ?? this.elapsed,
    viewers: viewers ?? this.viewers,
    isPaused: isPaused ?? this.isPaused,
  );

  @override
  List<Object?> get props => [topic, elapsed, viewers, isPaused];
}

class ChatMessage extends Equatable {
  final String id;
  final String user;
  final String text;
  final DateTime at;

  const ChatMessage({
    required this.id,
    required this.user,
    required this.text,
    required this.at,
  });

  @override
  List<Object?> get props => [id, user, text, at];
}

class GiftEvent extends Equatable {
  final String id;
  final String from;
  final String giftName;
  final int coins;

  const GiftEvent({
    required this.id,
    required this.from,
    required this.giftName,
    required this.coins,
  });

  @override
  List<Object?> get props => [id, from, giftName, coins];
}

class GuestJoinEvent extends Equatable {
  final String guestHandle;
  const GuestJoinEvent(this.guestHandle);
  @override
  List<Object?> get props => [guestHandle];
}
