// FILE: lib/features/livestream/presentation/widgets/live_settings_menu.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';
import 'package:moonlight/core/services/agora_service.dart';

// Ultra-modern TikTok-style settings menu
class LiveSettingsMenu extends StatefulWidget {
  final VoidCallback onClose;
  final AgoraService agora;

  const LiveSettingsMenu({
    super.key,
    required this.onClose,
    required this.agora,
  });

  @override
  State<LiveSettingsMenu> createState() => _LiveSettingsMenuState();
}

class _LiveSettingsMenuState extends State<LiveSettingsMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _hasListener = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    // Listen to Agora service changes
    if (!_hasListener) {
      widget.agora.addListener(_onAgoraStateChanged);
      _hasListener = true;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (_hasListener) {
      widget.agora.removeListener(_onAgoraStateChanged);
    }
    super.dispose();
  }

  void _onAgoraStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _closeMenu() {
    _animationController.reverse().then((_) {
      widget.onClose();
    });
  }

  // Unified FX settings method
  void _showFXSettings() {
    final bloc = context.read<LiveHostBloc>();
    final state = bloc.state;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return _FXBottomSheet(
          agora: widget.agora,
          currentState: state,
          onApply:
              (
                faceCleanEnabled,
                faceCleanLevel,
                brightenEnabled,
                brightenLevel,
              ) {
                // Dispatch to BLoC for persistence
                bloc.add(
                  BeautyPreferencesUpdated(
                    faceCleanEnabled: faceCleanEnabled,
                    faceCleanLevel: faceCleanLevel,
                    brightenEnabled: brightenEnabled,
                    brightenLevel: brightenLevel,
                  ),
                );

                // Apply immediately to Agora
                widget.agora.applyBeauty(
                  faceCleanEnabled: faceCleanEnabled,
                  faceCleanLevel: faceCleanLevel,
                  brightenEnabled: brightenEnabled,
                  brightenLevel: brightenLevel,
                );
              },
        );
      },
    ).then((_) {
      // Menu might need to be re-shown
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeMenu,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              alignment: Alignment.bottomRight,
              child: child,
            ),
          );
        },
        child: Align(
          alignment: Alignment.bottomRight,
          child: Container(
            margin: const EdgeInsets.only(right: 16, bottom: 100),
            child: _SettingsMenuContent(
              agora: widget.agora,
              onFXPressed: _showFXSettings,
              onClose: _closeMenu,
            ),
          ),
        ),
      ),
    );
  }
}

// Modern TikTok-style settings content
class _SettingsMenuContent extends StatelessWidget {
  final AgoraService agora;
  final VoidCallback onFXPressed;
  final VoidCallback onClose;

  const _SettingsMenuContent({
    required this.agora,
    required this.onFXPressed,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveHostBloc, LiveHostState>(
      builder: (context, state) {
        final hasBeautySettings =
            state.faceCleanEnabled != null ||
            state.brightenEnabled != null ||
            state.faceCleanLevel != null ||
            state.brightenLevel != null;

        // Check if beauty is currently active from Agora
        final beautyActive = agora.beautyActive.value;

        return Container(
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withOpacity(0.9),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: -10,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: onClose,
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Settings Items
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        // Audio Control
                        _ModernSettingsItem(
                          icon: agora.isMicEnabled
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                          label: agora.isMicEnabled
                              ? 'Mute Audio'
                              : 'Unmute Audio',
                          isActive: !agora.isMicEnabled, // Active when muted
                          color: !agora.isMicEnabled
                              ? const Color(0xFFFF6A00)
                              : Colors.white,
                          onTap: () => agora.setMicEnabled(!agora.isMicEnabled),
                        ),

                        // Video Control
                        _ModernSettingsItem(
                          icon: agora.isCameraEnabled
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          label: agora.isCameraEnabled
                              ? 'Hide Video'
                              : 'Show Video',
                          isActive:
                              !agora.isCameraEnabled, // Active when hidden
                          color: !agora.isCameraEnabled
                              ? const Color(0xFFFF6A00)
                              : Colors.white,
                          onTap: () =>
                              agora.setCameraEnabled(!agora.isCameraEnabled),
                        ),

                        // Beauty FX (Unified)
                        _ModernSettingsItem(
                          icon: Icons.face_retouching_natural_rounded,
                          label: 'Beauty FX',
                          isActive: beautyActive || hasBeautySettings,
                          color: (beautyActive || hasBeautySettings)
                              ? const Color(0xFFFF6A00)
                              : Colors.white,
                          onTap: onFXPressed,
                          badge: beautyActive
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6A00),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFF6A00,
                                        ).withOpacity(0.5),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
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

// Modern TikTok-style settings item
class _ModernSettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  final Widget? badge;

  const _ModernSettingsItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFFF6A00).withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFFF6A00).withOpacity(0.3)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, color: color, size: 20),
                      if (badge != null)
                        Positioned(top: 2, right: 2, child: badge!),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6A00),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6A00).withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Ultra-modern FX Settings Bottom Sheet
class _FXBottomSheet extends StatefulWidget {
  final AgoraService agora;
  final LiveHostState currentState;
  final Function(bool, int, bool, int) onApply;

  const _FXBottomSheet({
    required this.agora,
    required this.currentState,
    required this.onApply,
  });

  @override
  State<_FXBottomSheet> createState() => _FXBottomSheetState();
}

class _FXBottomSheetState extends State<_FXBottomSheet> {
  late bool _faceCleanEnabled;
  late int _faceCleanLevel;
  late bool _brightenEnabled;
  late int _brightenLevel;
  Timer? _applyTimer;

  @override
  void initState() {
    super.initState();

    // Initialize with current state from BLoC
    _faceCleanEnabled = widget.currentState.faceCleanEnabled ?? false;
    _faceCleanLevel = widget.currentState.faceCleanLevel ?? 40;
    _brightenEnabled = widget.currentState.brightenEnabled ?? false;
    _brightenLevel = widget.currentState.brightenLevel ?? 40;
  }

  @override
  void dispose() {
    _applyTimer?.cancel();
    super.dispose();
  }

  void _applyChanges() {
    widget.onApply(
      _faceCleanEnabled,
      _faceCleanLevel,
      _brightenEnabled,
      _brightenLevel,
    );
    Navigator.of(context).pop();
  }

  void _resetToDefaults() {
    setState(() {
      _faceCleanEnabled = false;
      _faceCleanLevel = 40;
      _brightenEnabled = false;
      _brightenLevel = 40;
    });

    // Apply reset immediately
    _applyImmediately();
  }

  void _applyImmediately() {
    // Cancel any pending timer
    _applyTimer?.cancel();

    // Apply immediately (no debounce for better UX)
    widget.onApply(
      _faceCleanEnabled,
      _faceCleanLevel,
      _brightenEnabled,
      _brightenLevel,
    );
  }

  void _debouncedApply() {
    _applyTimer?.cancel();
    _applyTimer = Timer(const Duration(milliseconds: 150), _applyImmediately);
  }

  void _updateFaceCleanLevel(double value) {
    setState(() {
      _faceCleanLevel = value.round();
    });
    // Debounce the apply to avoid too many calls
    _debouncedApply();
  }

  void _updateBrightenLevel(double value) {
    setState(() {
      _brightenLevel = value.round();
    });
    // Debounce the apply to avoid too many calls
    _debouncedApply();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.7,
      snap: true,
      snapSizes: const [0.5, 0.7],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F1218),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Beauty FX',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _resetToDefaults,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    // Face Clean
                    _FXSection(
                      icon: Icons.face_retouching_natural_rounded,
                      title: 'Face Clean',
                      enabled: _faceCleanEnabled,
                      level: _faceCleanLevel,
                      color: const Color(0xFF00D4FF),
                      onEnabledChanged: (value) {
                        setState(() => _faceCleanEnabled = value);
                        _applyImmediately();
                      },
                      onLevelChanged: _updateFaceCleanLevel,
                    ),

                    const SizedBox(height: 24),

                    // Brighten
                    _FXSection(
                      icon: Icons.wb_sunny_rounded,
                      title: 'Brighten',
                      enabled: _brightenEnabled,
                      level: _brightenLevel,
                      color: const Color(0xFFFFD700),
                      onEnabledChanged: (value) {
                        setState(() => _brightenEnabled = value);
                        _applyImmediately();
                      },
                      onLevelChanged: _updateBrightenLevel,
                    ),

                    const SizedBox(height: 32),

                    // Preview Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: const Color(0xFFFF6A00),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Changes apply instantly to your livestream',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Apply Button (for persistence)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF0F1218),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: _applyChanges,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFFF6A00), Color(0xFFFF3D00)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6A00).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Save Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Modern FX Section Component
class _FXSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool enabled;
  final int level;
  final Color color;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<double> onLevelChanged;

  const _FXSection({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.level,
    required this.color,
    required this.onEnabledChanged,
    required this.onLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? color.withOpacity(0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: enabled
                      ? color.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: enabled ? color : Colors.white.withOpacity(0.5),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: enabled
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: onEnabledChanged,
                activeColor: color,
                trackColor: MaterialStateProperty.all(color.withOpacity(0.3)),
              ),
            ],
          ),

          if (enabled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Intensity',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$level%',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: color.withOpacity(0.2),
                thumbColor: color,
                overlayColor: color.withOpacity(0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 10,
                  disabledThumbRadius: 8,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                valueIndicatorColor: color,
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              child: Slider(
                value: level.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: onLevelChanged,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Soft',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Natural',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Strong',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
