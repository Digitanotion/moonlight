// lib/features/livestream/presentation/widgets/viewers_panel.dart
import 'package:flutter/material.dart';

class ViewersPanel extends StatelessWidget {
  final int count;
  final List<Map<String, dynamic>> users;
  const ViewersPanel({super.key, required this.count, required this.users});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xEE0F142D),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BackButton(color: Colors.white),
              const Spacer(),
              const Icon(
                Icons.remove_red_eye_rounded,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...users.map(
            (u) => ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.white24),
              title: Text(
                u['display'] ?? '',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                u['role'] ?? '',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
