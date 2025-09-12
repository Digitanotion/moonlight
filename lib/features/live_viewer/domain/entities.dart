import 'package:equatable/equatable.dart';

class HostInfo extends Equatable {
  final String name;
  final String title; // "Talking about Mental Health"
  final String subtitle; // "Mental health Coach. 1.2M Fans"
  final String badge; // "Superstar"
  final String avatarUrl;
  final bool isFollowed;

  const HostInfo({
    required this.name,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.avatarUrl,
    this.isFollowed = false,
  });

  HostInfo copyWith({bool? isFollowed}) => HostInfo(
    name: name,
    title: title,
    subtitle: subtitle,
    badge: badge,
    avatarUrl: avatarUrl,
    isFollowed: isFollowed ?? this.isFollowed,
  );

  @override
  List<Object?> get props => [
    name,
    title,
    subtitle,
    badge,
    avatarUrl,
    isFollowed,
  ];
}

class ChatMessage extends Equatable {
  final String id;
  final String username;
  final String text;

  const ChatMessage({
    required this.id,
    required this.username,
    required this.text,
  });

  @override
  List<Object?> get props => [id, username, text];
}

class GuestJoinNotice extends Equatable {
  final String username; // "Jane_Star"
  final String message; // "has joined the stream as a guest!"
  const GuestJoinNotice({required this.username, required this.message});
  @override
  List<Object?> get props => [username, message];
}

class GiftNotice extends Equatable {
  final String from; // "Sarah"
  final String giftName; // "Golden Crown"
  final int coins; // 500
  const GiftNotice({
    required this.from,
    required this.giftName,
    required this.coins,
  });
  @override
  List<Object?> get props => [from, giftName, coins];
}
