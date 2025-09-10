// lib/features/livestream/presentation/widgets/pause_overlay_viewer.dart
import 'package:flutter/material.dart';

class PauseOverlayViewer extends StatelessWidget {
  final String hostDisplay;
  final String hostHandle;
  final VoidCallback onLeave;
  const PauseOverlayViewer({
    super.key,
    required this.hostDisplay,
    required this.hostHandle,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: const Color(0x990C0F24),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pause_circle_filled_rounded,
              color: Colors.white,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Stream Paused',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'The host has temporarily paused this livestream. Please stay tuned…',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            _viewerCard(hostDisplay, hostHandle),
            const SizedBox(height: 14),
            _outlineButton('Leave Stream', onLeave),
          ],
        ),
      ),
    );
  }

  static Widget _outlineButton(String text, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white54, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static Widget _viewerCard(String name, String handle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x33222A4D),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 18, backgroundColor: Colors.white24),
          const SizedBox(width: 8),
          Text(
            '@$handle',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6A3DF7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Superstar',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
