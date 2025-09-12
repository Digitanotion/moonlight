// -----------------------------
// FILE: lib/features/live/ui/live_viewer_page.dart
// -----------------------------
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/presentation/widgets/chat_list.dart';
import 'package:moonlight/features/livestream/presentation/widgets/comment_input.dart';
import 'package:moonlight/features/livestream/presentation/widgets/gift_banner.dart';
import 'package:moonlight/features/livestream/presentation/widgets/guest_banner.dart';
import 'package:moonlight/features/livestream/presentation/widgets/pause_overlay.dart';
import 'package:moonlight/features/livestream/presentation/widgets/request_button.dart';
import 'package:moonlight/features/livestream/presentation/widgets/top_bar.dart';
import '../../domain/entities/live_entities.dart';
import '../../domain/repositories/live_repository.dart';

class LiveViewerPage extends StatelessWidget {
  const LiveViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // Background (use provided screenshot for fast pixel-perfect demo)
          // In LiveViewerPage build() Stack children, replace the background:
          Positioned.fill(
            child: Image.asset(
              'assets/images/onboard_1.jpg',
              fit: BoxFit.cover,
              // Fallback so UI is still visible if asset path is wrong or asset not bundled
              errorBuilder: (context, error, stack) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Background image missing',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              },
            ),
          ),

          // Frosted top bar
          const Positioned(top: 12, left: 0, right: 0, child: LiveTopBar()),

          // Right side actions (likes/share counters)
          Positioned(right: 12, bottom: 180, child: _RightSideCounters()),

          // Chat panel
          const Positioned(left: 12, right: 12, bottom: 130, child: ChatList()),

          // Banners (gift, guest join)
          const Positioned(top: 120, left: 16, right: 16, child: GuestBanner()),
          const Positioned(top: 170, left: 16, right: 16, child: GiftBanner()),

          // Request to join button
          const Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: RequestToJoinButton(),
          ),

          // Comment input row
          const Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: CommentInput(),
          ),

          // Pause overlay (switches based on state)
          const PauseOverlay(),

          // Debug toggle (long-press to simulate pause/resume)
          Positioned(top: size.height * .35, right: 0, child: _PauseDebugBtn()),
        ],
      ),
    );
  }
}

class _RightSideCounters extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    pill(IconData icon, String text) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
    return Column(
      children: [
        pill(Icons.favorite_border, '23.5k'),
        pill(Icons.ios_share, '1.2k'),
      ],
    );
  }
}

class _PauseDebugBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        final repo = context.read<LiveRepository>();
        if (repo is! dynamic) return; // ignore
        if (repo is Function) return;
        // invoke toggle when using mock
        try {
          (repo as dynamic).togglePause();
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.pause_circle_outline, color: Colors.white),
      ),
    );
  }
}
