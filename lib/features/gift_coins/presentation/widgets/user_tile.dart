// lib/features/gift_coins/presentation/widgets/user_tile.dart
import 'package:flutter/material.dart';
import '../../domain/entities/gift_user.dart';

class UserTile extends StatelessWidget {
  final GiftUser user;
  final VoidCallback? onTap;
  const UserTile({Key? key, required this.user, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(user.avatar),
      ),
      title: Text(
        user.username,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        user.fullName,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}
