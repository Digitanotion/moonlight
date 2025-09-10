// lib/features/livestream/presentation/widgets/bottom_actions_bar.dart
import 'package:flutter/material.dart';

class BottomActionsBar extends StatelessWidget {
  final VoidCallback onChat;
  final VoidCallback onViewers;
  final VoidCallback onGifts;
  final VoidCallback onPauseOrResume;
  final bool paused;
  final VoidCallback onEndOrLeave;
  final bool isHost;

  const BottomActionsBar({
    super.key,
    required this.onChat,
    required this.onViewers,
    required this.onGifts,
    required this.onPauseOrResume,
    required this.paused,
    required this.onEndOrLeave,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(color: Color(0x22121A3F)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _pill(Icons.chat_bubble_rounded, 'Chat', onChat),
            _pill(Icons.groups_rounded, 'Viewers', onViewers),
            _pill(Icons.card_giftcard_rounded, 'Gifts', onGifts),
            _pill(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              paused ? 'Resume' : 'Pause',
              onPauseOrResume,
            ),
            _pill(
              isHost ? Icons.stop_rounded : Icons.logout_rounded,
              isHost ? 'End' : 'Leave',
              onEndOrLeave,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData i, String t, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0x22121A3F),
            shape: BoxShape.circle,
          ),
          child: Icon(i, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    ),
  );
}
