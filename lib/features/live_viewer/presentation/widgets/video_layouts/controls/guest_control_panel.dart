// guest_control_panel.dart - TIKTOK STYLE ULTRA-MODERN
import 'package:flutter/material.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';

class GuestControlPanel extends StatefulWidget {
  final AgoraViewerService agoraService;
  final VoidCallback onEndCall;

  const GuestControlPanel({
    super.key,
    required this.agoraService,
    required this.onEndCall,
  });

  @override
  State<GuestControlPanel> createState() => _GuestControlPanelState();
}

class _GuestControlPanelState extends State<GuestControlPanel> {
  bool _isAudioMuted = true;
  bool _isVideoEnabled = false;
  bool _isVisible = true;
  bool _showLabels = false;
  bool _showControlPanel = false;

  @override
  void initState() {
    super.initState();
    _isAudioMuted = widget.agoraService.isMicMuted;
    _isVideoEnabled = !widget.agoraService.isCamMuted;
  }

  void _toggleAudio() async {
    final newState = !_isAudioMuted;
    setState(() => _isAudioMuted = newState);
    await widget.agoraService.setMicEnabled(!newState);
  }

  void _toggleVideo() async {
    final newState = !_isVideoEnabled;
    setState(() => _isVideoEnabled = newState);
    await widget.agoraService.setCamEnabled(newState);
  }

  void _toggleLabels() {
    setState(() => _showLabels = !_showLabels);
  }

  void _hideTemporarily() {
    setState(() => _isVisible = false);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _isVisible ? 20 : -100,
      right: 20,
      left: 20,
      child: AnimatedOpacity(
        opacity: _isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: isSmallScreen ? 66 : 74,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Audio Control - Ultra Minimal
              _ModernControlButton(
                icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
                isActive: !_isAudioMuted,
                onTap: _toggleAudio,
                label: _isAudioMuted ? 'Tap to unmute' : 'Tap to mute',
                showLabel: _showLabels,
                size: isSmallScreen ? 20 : 22,
              ),

              // Divider
              Container(
                width: 1,
                height: 24,
                color: Colors.white.withOpacity(0.15),
              ),

              // Video Control - Ultra Minimal
              _ModernControlButton(
                icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                isActive: _isVideoEnabled,
                onTap: _toggleVideo,
                label: _isVideoEnabled ? 'Tap to turn off' : 'Tap to turn on',
                showLabel: _showLabels,
                size: isSmallScreen ? 20 : 22,
              ),

              // Divider
              Container(
                width: 1,
                height: 24,
                color: Colors.white.withOpacity(0.15),
              ),

              // End Call - Subtle but distinct
              _ModernControlButton(
                icon: Icons.call_end_rounded,
                isActive: false,
                onTap: widget.onEndCall,
                label: 'Leave Now',
                showLabel: _showLabels,
                size: isSmallScreen ? 20 : 22,
                isEndCall: true,
              ),

              // Info toggle button
              GestureDetector(
                onTap: _toggleLabels,
                onLongPress: _hideTemporarily,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: Icon(
                    _showLabels ? Icons.info : Icons.info_outline,
                    size: 18,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String label;
  final bool showLabel;
  final double size;
  final bool isEndCall;

  const _ModernControlButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.label,
    required this.showLabel,
    required this.size,
    this.isEndCall = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        // Optional: Add haptic feedback on long press
        // HapticFeedback.lightImpact();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Button with subtle animation
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEndCall
                  ? Colors.red.withOpacity(0.2)
                  : isActive
                  ? Colors.white.withOpacity(0.15)
                  : Colors.transparent,
              border: Border.all(
                color: isEndCall
                    ? Colors.red.withOpacity(0.4)
                    : isActive
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.15),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: size,
                color: isEndCall
                    ? Colors.red
                    : isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.9),
              ),
            ),
          ),

          // Minimal label that appears on hover/toggle
          AnimatedOpacity(
            opacity: showLabel ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Alternative: Floating action button style (even more minimal)
class TikTokStyleControls extends StatefulWidget {
  final AgoraViewerService agoraService;
  final VoidCallback onEndCall;

  const TikTokStyleControls({
    super.key,
    required this.agoraService,
    required this.onEndCall,
  });

  @override
  State<TikTokStyleControls> createState() => _TikTokStyleControlsState();
}

class _TikTokStyleControlsState extends State<TikTokStyleControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isExpanded = false;
  bool _isAudioMuted = true;
  bool _isVideoEnabled = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _isAudioMuted = widget.agoraService.isMicMuted;
    _isVideoEnabled = !widget.agoraService.isCamMuted;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _toggleAudio() async {
    final newState = !_isAudioMuted;
    setState(() => _isAudioMuted = newState);
    await widget.agoraService.setMicEnabled(!newState);
  }

  void _toggleVideo() async {
    final newState = !_isVideoEnabled;
    setState(() => _isVideoEnabled = newState);
    await widget.agoraService.setCamEnabled(newState);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main control button
        Positioned(
          bottom: 24,
          right: 16,
          child: GestureDetector(
            onTap: _toggleExpand,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _animationController,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),

        // Expanded controls
        Positioned(
          bottom: 90,
          right: 28,
          child: AnimatedOpacity(
            opacity: _isExpanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Audio button
                _FloatingControl(
                  icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
                  label: _isAudioMuted ? 'Unmute' : 'Mute',
                  onTap: _toggleAudio,
                  isActive: !_isAudioMuted,
                  delay: 0,
                  isVisible: _isExpanded,
                ),
                const SizedBox(height: 12),

                // Video button
                _FloatingControl(
                  icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  label: _isVideoEnabled ? 'Camera Off' : 'Camera On',
                  onTap: _toggleVideo,
                  isActive: _isVideoEnabled,
                  delay: 50,
                  isVisible: _isExpanded,
                ),
                const SizedBox(height: 12),

                // End call button
                _FloatingControl(
                  icon: Icons.call_end_rounded,
                  label: 'End',
                  onTap: widget.onEndCall,
                  isActive: false,
                  isEndCall: true,
                  delay: 100,
                  isVisible: _isExpanded,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isEndCall;
  final int delay;
  final bool isVisible;

  const _FloatingControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isEndCall = false,
    this.delay = 0,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: Duration(milliseconds: 300 + delay),
      curve: Curves.easeOutBack,
      offset: isVisible ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 200 + delay),
        opacity: isVisible ? 1.0 : 0.0,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isEndCall
                    ? Colors.red.withOpacity(0.4)
                    : isActive
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isEndCall
                      ? Colors.red
                      : isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
