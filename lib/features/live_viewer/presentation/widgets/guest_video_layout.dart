// lib/features/live_viewer/presentation/widgets/guest_video_layout.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/live_viewer/domain/video_surface_provider.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

/// A dedicated widget that handles the guest video layout and controls
class GuestVideoLayout extends StatefulWidget {
  const GuestVideoLayout({super.key});

  @override
  State<GuestVideoLayout> createState() => _GuestVideoLayoutState();
}

class _GuestVideoLayoutState extends State<GuestVideoLayout> {
  bool _isGuestControlsVisible = true;
  bool _isMicMuted = true;
  bool _isCamMuted = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (previous, current) =>
          previous.activeGuestUuid != current.activeGuestUuid ||
          previous.currentRole != current.currentRole,
      builder: (context, state) {
        final iAmGuest =
            state.currentRole == 'guest' || state.currentRole == 'cohost';
        final anyGuest = state.activeGuestUuid != null || iAmGuest;

        // 🔥 CRITICAL: Only show guest layout when we're actively in guest mode
        if (!anyGuest) {
          // Return empty - normal view will be shown by BackgroundVideo
          return const SizedBox.shrink();
        }

        // Only show guest layout if we're not transitioning back
        if (state.currentRole == 'audience' || state.currentRole == 'viewer') {
          // Small delay to allow transition
          return const SizedBox.shrink();
        }

        return Text('');
      },
    );
  }

  Widget _buildHostVideoSection() {
    final repo = context.read<ViewerBloc>().repo;
    final vp = repo is VideoSurfaceProvider
        ? repo as VideoSurfaceProvider
        : null;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          vp?.buildHostVideo() ?? _buildVideoPlaceholder('HOST'),
          // Debug label
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestVideoSection({
    required bool isLocalGuest,
    required double videoHeight,
  }) {
    final repo = context.read<ViewerBloc>().repo;
    final vp = repo is VideoSurfaceProvider
        ? repo as VideoSurfaceProvider
        : null;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          isLocalGuest
              ? (vp?.buildLocalPreview() ??
                    _buildVideoPlaceholder('YOU (GUEST)'))
              : (vp?.buildGuestVideo() ?? _buildVideoPlaceholder('GUEST')),
          // Debug label
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isLocalGuest ? 'YOU (GUEST)' : 'GUEST',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestControls() {
    final repo = context.read<ViewerBloc>().repo;
    final vp = repo is VideoSurfaceProvider
        ? repo as VideoSurfaceProvider
        : null;

    if (vp == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlButton(
            icon: Icons.mic,
            isActive: !_isMicMuted,
            onTap: () async {
              final newState = !_isMicMuted;
              setState(() => _isMicMuted = newState);
              await vp.setMicEnabled(!newState);
            },
            label: _isMicMuted ? 'Unmute' : 'Mute',
          ),
          const SizedBox(width: 12),
          _buildControlButton(
            icon: Icons.videocam,
            isActive: !_isCamMuted,
            onTap: () async {
              final newState = !_isCamMuted;
              setState(() => _isCamMuted = newState);
              await vp.setCamEnabled(!newState);
            },
            label: _isCamMuted ? 'Camera On' : 'Camera Off',
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                _isGuestControlsVisible = false;
              });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _isGuestControlsVisible = true;
                  });
                }
              });
            },
            icon: const Icon(Icons.visibility_off, size: 16),
            color: Colors.white70,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFFF7A00).withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? const Color(0xFFFF7A00)
                    : Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? const Color(0xFFFF7A00) : Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFFFF7A00) : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlaceholder(String label) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Video loading...',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
