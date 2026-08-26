// lib/features/live_viewer/presentation/widgets/overlays/follow_prompt_overlay.dart
//
// Doc item 7: "At interval during livestream, a popup will appear asking
// viewers to follow the streamer." Periodic, dismissable, non-blocking —
// shows every ~90s for ~6s, only while the viewer isn't already
// following, using the existing FollowToggled event (already wired to
// repo.toggleFollow via ViewerBloc._onFollowToggled — nothing new needed
// at the data layer).

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

class FollowPromptOverlay extends StatefulWidget {
  const FollowPromptOverlay({super.key});

  @override
  State<FollowPromptOverlay> createState() => _FollowPromptOverlayState();
}

class _FollowPromptOverlayState extends State<FollowPromptOverlay> {
  static const _interval = Duration(seconds: 90);

  Timer? _showTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _scheduleNextShow();
  }

  void _scheduleNextShow() {
    _showTimer?.cancel();
    _showTimer = Timer(_interval, () {
      if (!mounted) return;
      final isFollowed =
          context.read<ViewerBloc>().state.host?.isFollowed ?? true;
      if (isFollowed) {
        // Already following — skip this cycle, check again next interval.
        _scheduleNextShow();
        return;
      }
      // Stays up until the viewer explicitly dismisses it (× or Follow) —
      // no auto-hide timer.
      setState(() => _visible = true);
    });
  }

  void _dismiss() {
    setState(() => _visible = false);
    _scheduleNextShow();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return BlocConsumer<ViewerBloc, ViewerState>(
      listenWhen: (p, n) =>
          p.host?.isFollowed != n.host?.isFollowed ||
          p.followErrorMessage != n.followErrorMessage,
      listener: (context, state) {
        if (state.host?.isFollowed == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Now following ${state.host?.name ?? 'streamer'}'),
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() => _visible = false);
          _scheduleNextShow();
        } else if (state.followErrorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.followErrorMessage!),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 2),
            ),
          );
          // Banner stays up — genuinely didn't work, let them try again.
        }
      },
      buildWhen: (p, n) => p.host != n.host,
      builder: (context, state) {
        final host = state.host;
        if (host == null || host.isFollowed) return const SizedBox.shrink();

        return Positioned(
          top: 80,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipOval(
                      child: host.avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: host.avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.person, color: Colors.white70, size: 18),
                            )
                          : const Icon(Icons.person, color: Colors.white70, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Follow ${host.name} to see more from them',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                                   ElevatedButton(
                    onPressed: () {
                      context.read<ViewerBloc>().add(const FollowToggled());
                      // No longer dismissing here immediately — the
                      // BlocConsumer listener above now dismisses only
                      // on a confirmed successful follow, or shows an
                      // error and leaves the banner up if it genuinely
                      // failed.
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Follow',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}