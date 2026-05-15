// lib/features/live_viewer/presentation/widgets/video_layouts/controls/guest_control_panel.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';

/// Shows a bottom-sheet style control panel for guests (co-hosts).
/// Call [showGuestControlSheet] from any context — no positioning needed.
void showGuestControlSheet(
  BuildContext context, {
  required AgoraViewerService agoraService,
  required VoidCallback onEndCall,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (_) =>
        _GuestControlSheet(agoraService: agoraService, onEndCall: onEndCall),
  );
}

class _GuestControlSheet extends StatefulWidget {
  final AgoraViewerService agoraService;
  final VoidCallback onEndCall;

  const _GuestControlSheet({
    required this.agoraService,
    required this.onEndCall,
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
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Co-host Controls',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // Controls row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlTile(
                    icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                    label: _isMicMuted ? 'Unmute Mic' : 'Mute Mic',
                    isDestructive: _isMicMuted,
                    onTap: _toggleMic,
                  ),
                  _ControlTile(
                    icon: _isCamOff ? Icons.videocam_off : Icons.videocam,
                    label: _isCamOff ? 'Enable Camera' : 'Disable Camera',
                    isDestructive: _isCamOff,
                    onTap: _toggleCam,
                  ),
                  _ControlTile(
                    icon: Icons.call_end_rounded,
                    label: 'Leave',
                    isDestructive: true,
                    isEndCall: true,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onEndCall();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final bool isEndCall;
  final VoidCallback onTap;

  const _ControlTile({
    required this.icon,
    required this.label,
    required this.isDestructive,
    required this.onTap,
    this.isEndCall = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isEndCall
        ? Colors.red
        : isDestructive
        ? Colors.orange
        : Colors.white;

    final bgColor = isEndCall
        ? Colors.red.withOpacity(0.12)
        : isDestructive
        ? Colors.orange.withOpacity(0.1)
        : Colors.white.withOpacity(0.08);

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
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
