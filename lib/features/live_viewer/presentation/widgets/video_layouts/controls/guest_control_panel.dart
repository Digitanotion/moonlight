// lib/features/live_viewer/presentation/widgets/video_layouts/controls/guest_control_panel.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';

/// Controls for a guest in the box: mic, camera, step out of the box (keep
/// watching) or leave the live entirely.
void showGuestControlSheet(
  BuildContext context, {
  required AgoraViewerService agoraService,
  required VoidCallback onEndCall,
  VoidCallback? onLeaveBox,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _GuestControlSheet(
      agoraService: agoraService,
      onEndCall: onEndCall,
      onLeaveBox: onLeaveBox,
    ),
  );
}

class _GuestControlSheet extends StatefulWidget {
  final AgoraViewerService agoraService;
  final VoidCallback onEndCall;
  final VoidCallback? onLeaveBox;

  const _GuestControlSheet({
    required this.agoraService,
    required this.onEndCall,
    this.onLeaveBox,
  });

  @override
  State<_GuestControlSheet> createState() => _GuestControlSheetState();
}

class _GuestControlSheetState extends State<_GuestControlSheet> {
  late bool _isMicMuted;
  late bool _isCamOff;

  @override
  void initState() {
    super.initState();
    _isMicMuted = widget.agoraService.isMicMuted;
    _isCamOff = widget.agoraService.isCamMuted;
  }

  Future<void> _toggleMic() async {
    final next = !_isMicMuted;
    setState(() => _isMicMuted = next);
    await widget.agoraService.setMicEnabled(!next);
  }

  Future<void> _toggleCam() async {
    final next = !_isCamOff;
    setState(() => _isCamOff = next);
    await widget.agoraService.setCamEnabled(!next);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF14101F).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'You\'re in the box',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Everyone watching can see and hear you',
                    style: TextStyle(color: Colors.white54, fontSize: 12.5),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlTile(
                        icon: _isMicMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: _isMicMuted ? 'Unmute' : 'Mute',
                        warn: _isMicMuted,
                        onTap: _toggleMic,
                      ),
                      _ControlTile(
                        icon: _isCamOff
                            ? Icons.videocam_off_rounded
                            : Icons.videocam_rounded,
                        label: _isCamOff ? 'Camera on' : 'Camera off',
                        warn: _isCamOff,
                        onTap: _toggleCam,
                      ),
                      if (widget.onLeaveBox != null)
                        _ControlTile(
                          icon: Icons.logout_rounded,
                          label: 'Leave box',
                          warn: true,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onLeaveBox!();
                          },
                        ),
                      _ControlTile(
                        icon: Icons.call_end_rounded,
                        label: 'Leave live',
                        danger: true,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onEndCall();
                        },
                      ),
                    ],
                  ),
                  if (widget.onLeaveBox != null) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Leave box: step off camera and keep watching.',
                      style: TextStyle(color: Colors.white38, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool warn;
  final bool danger;
  final VoidCallback onTap;

  const _ControlTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.warn = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFFF2D55)
        : warn
        ? const Color(0xFFFFB020)
        : Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: danger
                  ? color
                  : color.withValues(alpha: warn ? 0.14 : 0.1),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: danger ? Colors.white : color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
