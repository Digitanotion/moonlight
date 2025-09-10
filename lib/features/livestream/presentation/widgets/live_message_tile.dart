// lib/features/livestream/presentation/widgets/live_message_tile.dart
import 'package:flutter/material.dart';
import '../../domain/entities/message.dart';

class LiveMessageTile extends StatelessWidget {
  const LiveMessageTile({super.key, required this.msg});
  final Message msg;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // avatar
        CircleAvatar(
          radius: 16,
          backgroundImage:
              (msg.userAvatarUrl != null && msg.userAvatarUrl!.isNotEmpty)
              ? NetworkImage(msg.userAvatarUrl!)
              : null,
          child: (msg.userAvatarUrl == null || msg.userAvatarUrl!.isEmpty)
              ? const Icon(Icons.person, size: 16)
              : null,
        ),
        const SizedBox(width: 10),
        // name + text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.userDisplay,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                msg.text,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        // (optional) timestamp / gift chip etc.
      ],
    );
  }
}
