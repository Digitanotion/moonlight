// FILE: lib/features/livestream/presentation/widgets/live_settings_menu.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';
import 'package:moonlight/core/services/agora_service.dart';

// ─── LiveSettingsMenu ─────────────────────────────────────────────────────────

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
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _opacityAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
    widget.agora.addListener(_onAgoraChanged);
  }

  @override
  void dispose() {
    widget.agora.removeListener(_onAgoraChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onAgoraChanged() {
    if (mounted) setState(() {});
  }

  void _closeMenu() {
    // Guard: widget may already be gone when the reverse completes.
    _animController.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  void _showFXSettings() {
    // Capture BLoC before going async — context may change.
    final bloc = context.read<LiveHostBloc>();
    final state = bloc.state;
    final agora = widget.agora;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _FXBottomSheet(
        agora: agora,
        currentState: state,
        onApply: (faceOn, faceLevel, brightOn, brightLevel) {
          // BLoC — persists the settings.
          bloc.add(
            BeautyPreferencesUpdated(
              faceCleanEnabled: faceOn,
              faceCleanLevel: faceLevel,
              brightenEnabled: brightOn,
              brightenLevel: brightLevel,
            ),
          );
          // Agora — applies immediately; never throws (handled internally).
          agora.applyBeauty(
            faceCleanEnabled: faceOn,
            faceCleanLevel: faceLevel,
            brightenEnabled: brightOn,
            brightenLevel: brightLevel,
          );
        },
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeMenu,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) => Opacity(
          opacity: _opacityAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            alignment: Alignment.bottomRight,
            child: child,
          ),
        ),
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

// ─── _SettingsMenuContent ─────────────────────────────────────────────────────

class _SettingsMenuContent extends StatelessWidget {
  final AgoraService agora;
  final VoidCallback onFXPressed;
  final VoidCallback onClose;

  const _SettingsMenuContent({
    required this.agora,
    required this.onFXPressed,
    required this.onClose,
  });

  // Emergency reset — called after confirmation dialog closes.
  // Uses a [BuildContext] captured at the point of the tap, not from an async
  // gap, so it is always valid when _performReset is first entered.
  Future<void> _performReset(BuildContext context) async {
    // Capture the bloc before any await so we don't access context across gaps.
    LiveHostBloc? bloc;
    try {
      bloc = BlocProvider.of<LiveHostBloc>(context);
    } catch (_) {
      // BLoC may have been removed from the tree — continue reset without it.
    }

    // Show progress overlay.
    OverlayEntry? overlay;
    try {
      overlay = OverlayEntry(
        builder: (_) => Positioned(
          bottom: 100,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Resetting camera…',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      Overlay.of(context).insert(overlay);
    } catch (e) {
      debugPrint('[Reset] Could not show overlay: $e');
    }

    try {
      await agora.resetBeauty();

      bloc?.add(
        BeautyPreferencesUpdated(
          faceCleanEnabled: false,
          faceCleanLevel: 40,
          brightenEnabled: false,
          brightenLevel: 40,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      overlay?.remove();
      overlay = null;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera successfully reset'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      overlay?.remove();
      overlay = null;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveHostBloc, LiveHostState>(
      builder: (context, state) {
        final hasBeautySettings =
            state.faceCleanEnabled || state.brightenEnabled;
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
                  // ── Header ─────────────────────────────────────────────────
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

                  // ── Items ──────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        _MenuItem(
                          icon: agora.isMicEnabled
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                          label: agora.isMicEnabled
                              ? 'Mute Audio'
                              : 'Unmute Audio',
                          isActive: !agora.isMicEnabled,
                          color: !agora.isMicEnabled
                              ? const Color(0xFFFF6A00)
                              : Colors.white,
                          onTap: () => agora.setMicEnabled(!agora.isMicEnabled),
                        ),
                        _MenuItem(
                          icon: agora.isCameraEnabled
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          label: agora.isCameraEnabled
                              ? 'Hide Video'
                              : 'Show Video',
                          isActive: !agora.isCameraEnabled,
                          color: !agora.isCameraEnabled
                              ? const Color(0xFFFF6A00)
                              : Colors.white,
                          onTap: () =>
                              agora.setCameraEnabled(!agora.isCameraEnabled),
                        ),
                        _MenuItem(
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

// ─── _MenuItem ────────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  final Widget? badge;

  const _MenuItem({
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
                  style: const TextStyle(
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

// ─── _FXBottomSheet ───────────────────────────────────────────────────────────
//
// Design invariants that prevent crashes:
//
//  1. onApply is called with a typedef so the reference stays valid after the
//     sheet is dismissed.
//  2. Single debounce timer (_debounce) — no competing timers.
//  3. Toggle changes call _applyNow() (no debounce) so a disable is never
//     delayed or swallowed.
//  4. Slider drags are debounced (350 ms) to avoid flooding the SDK.
//  5. Save / Reset / close all flush the timer and call _applyNow() first.
//  6. dispose() cancels the timer — no callbacks fire after the sheet is gone.

typedef _OnApply =
    void Function(bool faceOn, int faceLevel, bool brightOn, int brightLevel);

class _FXBottomSheet extends StatefulWidget {
  final AgoraService agora;
  final LiveHostState currentState;
  final _OnApply onApply;

  const _FXBottomSheet({
    required this.agora,
    required this.currentState,
    required this.onApply,
  });

  @override
  State<_FXBottomSheet> createState() => _FXBottomSheetState();
}

class _FXBottomSheetState extends State<_FXBottomSheet> {
  late bool _faceOn;
  late int _faceLevel;
  late bool _brightOn;
  late int _brightLevel;

  Timer? _debounce;
  static const _kDebounce = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    _faceOn = widget.currentState.faceCleanEnabled;
    _faceLevel = widget.currentState.faceCleanLevel;
    _brightOn = widget.currentState.brightenEnabled;
    _brightLevel = widget.currentState.brightenLevel;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Fire immediately — used for toggle changes and explicit save/reset.
  void _applyNow() {
    _debounce?.cancel();
    _debounce = null;
    widget.onApply(_faceOn, _faceLevel, _brightOn, _brightLevel);
  }

  /// Debounced — used for slider drags to avoid flooding the Agora SDK.
  void _applyDebounced() {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () {
      if (mounted) {
        widget.onApply(_faceOn, _faceLevel, _brightOn, _brightLevel);
      }
    });
  }

  // ── Toggle handlers ────────────────────────────────────────────────────────

  void _toggleFace(bool value) {
    if (!mounted) return;
    setState(() => _faceOn = value);
    _applyNow(); // immediate — disable must never be delayed
  }

  void _toggleBright(bool value) {
    if (!mounted) return;
    setState(() => _brightOn = value);
    _applyNow();
  }

  // ── Slider handlers ────────────────────────────────────────────────────────

  void _slideFace(double value) {
    if (!mounted) return;
    setState(() => _faceLevel = value.round());
    _applyDebounced();
  }

  void _slideBright(double value) {
    if (!mounted) return;
    setState(() => _brightLevel = value.round());
    _applyDebounced();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _reset() {
    if (!mounted) return;
    setState(() {
      _faceOn = false;
      _faceLevel = 40;
      _brightOn = false;
      _brightLevel = 40;
    });
    _applyNow();
  }

  void _saveAndClose() {
    _applyNow(); // flush any pending debounce before closing
    if (mounted) Navigator.of(context).pop();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.7,
      snap: true,
      snapSizes: const [0.5, 0.7],
      builder: (_, scrollController) {
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
                      onTap: _reset,
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
                      onTap: _saveAndClose,
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
                    _FXSection(
                      icon: Icons.face_retouching_natural_rounded,
                      title: 'Face Clean',
                      enabled: _faceOn,
                      level: _faceLevel,
                      color: const Color(0xFF00D4FF),
                      onEnabledChanged: _toggleFace,
                      onLevelChanged: _slideFace,
                    ),
                    const SizedBox(height: 24),
                    _FXSection(
                      icon: Icons.wb_sunny_rounded,
                      title: 'Brighten',
                      enabled: _brightOn,
                      level: _brightLevel,
                      color: const Color(0xFFFFD700),
                      onEnabledChanged: _toggleBright,
                      onLevelChanged: _slideBright,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFFF6A00),
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

              // Save button
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1218),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: _saveAndClose,
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

// ─── _FXSection ───────────────────────────────────────────────────────────────

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
          // Toggle row
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
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

          // Slider — animated reveal
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: enabled
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
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
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
