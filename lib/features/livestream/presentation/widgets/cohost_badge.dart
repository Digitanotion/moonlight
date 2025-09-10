// lib/features/livestream/presentation/widgets/cohost_badge.dart
import 'package:flutter/material.dart';

class CohostBadge extends StatelessWidget {
  final String label;
  final bool muted;
  const CohostBadge({super.key, required this.label, this.muted = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x66212B4F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
          if (muted) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.mic_off_rounded,
              color: Colors.redAccent,
              size: 14,
            ),
          ],
        ],
      ),
    );
  }
}
