// lib/features/live_viewer/presentation/widgets/controls/guest_controls_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/role_change_service.dart';

class GuestControlsPanel extends StatefulWidget {
  const GuestControlsPanel({super.key});

  @override
  State<GuestControlsPanel> createState() => _GuestControlsPanelState();
}

class _GuestControlsPanelState extends State<GuestControlsPanel> {
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ViewerBloc>();
    final liveStreamService = bloc.liveStreamService;
    final roleChangeService = bloc.roleChangeService;

    if (liveStreamService == null || roleChangeService == null) {
      return const SizedBox.shrink();
    }

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
            isActive: !roleChangeService.guestAudioMuted.value,
            onTap: () => bloc.add(
              GuestAudioToggled(!roleChangeService.guestAudioMuted.value),
            ),
            label: roleChangeService.guestAudioMuted.value ? 'Mute' : 'Unmute',
          ),
          const SizedBox(width: 12),
          _buildControlButton(
            icon: Icons.videocam,
            isActive: !roleChangeService.guestVideoMuted.value,
            onTap: () => bloc.add(
              GuestVideoToggled(!roleChangeService.guestVideoMuted.value),
            ),
            label: roleChangeService.guestVideoMuted.value
                ? 'Camera Off'
                : 'Camera On',
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
}
