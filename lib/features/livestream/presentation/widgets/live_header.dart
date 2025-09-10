// lib/features/livestream/presentation/widgets/live_header_bar.dart
import 'package:flutter/material.dart';

class LiveHeaderBar extends StatelessWidget {
  final String title;
  final String hostName;
  final String? hostAvatar;
  final int viewers;
  final Duration elapsed;
  final VoidCallback onClose;
  const LiveHeaderBar({
    super.key,
    required this.title,
    required this.hostName,
    this.hostAvatar,
    required this.viewers,
    required this.elapsed,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return SafeArea(
      bottom: false,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(color: Color(0x33121A3F)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$mm:$ss',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.remove_red_eye_rounded,
              color: Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text('$viewers', style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
