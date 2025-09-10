// lib/features/livestream/presentation/widgets/resume_overlay_host.dart
import 'package:flutter/material.dart';

class ResumeOverlayHost extends StatelessWidget {
  final VoidCallback onResume;
  const ResumeOverlayHost({super.key, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xB30C0F24),
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
              'Viewers will be notified when you resume your stream.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onResume,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A1A),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55FF7A1A),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Resume Stream',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
