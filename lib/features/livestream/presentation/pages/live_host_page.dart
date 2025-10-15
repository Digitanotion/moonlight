import 'dart:ui';
// import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/features/livestream/domain/entities/live_join_request.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';
import 'package:moonlight/features/livestream/domain/session/live_session_tracker.dart';
import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LiveHostPage extends StatefulWidget {
  final String hostName;
  final String hostBadge; // e.g., "Superstar"

  final String topic; // e.g., "Talking about Mental Health"
  final int initialViewers;
  final String startedAtIso;
  final String? avatarUrl; // optional for header

  const LiveHostPage({
    super.key,
    required this.hostName,
    required this.hostBadge,
    required this.topic,
    required this.initialViewers,
    required this.startedAtIso,
    this.avatarUrl,
  });

  @override
  State<LiveHostPage> createState() => _LiveHostPageState();
}

class _LiveHostPageState extends State<LiveHostPage>
    with WidgetsBindingObserver {
  // CameraController? _controller;
  // List<CameraDescription> _cameras = const [];
  bool _initErr = false;
  final AgoraService agora =
      GetIt.I<AgoraService>(); // FIXED: Declare agora here
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _showSettingsMenu = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Prevent screen from sleeping during live stream
    WakelockPlus.enable();
    // schedule event once the widget is mounted & provider is in the tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LiveHostBloc>().add(
        LiveStarted(
          widget.topic,
          initialViewers: widget.initialViewers,
          startedAtIso: widget.startedAtIso,
        ),
      );
    });
  }

  // Future<void> _setupCamera() async {
  //   try {
  //     _cameras = await availableCameras();
  //     final front = _cameras.firstWhere(
  //       (c) => c.lensDirection == CameraLensDirection.front,
  //       orElse: () => _cameras.first,
  //     );
  //     _controller = CameraController(
  //       front,
  //       ResolutionPreset.high,
  //       enableAudio: true,
  //     );
  //     await _controller!.initialize();
  //     if (mounted) setState(() {});
  //   } catch (_) {
  //     _initErr = true;
  //     if (mounted) setState(() {});
  //   }
  // }

  @override
  void dispose() {
    // _controller?.dispose();
    // Re-enable screen sleep when leaving live stream
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-enable wakelock when app comes to foreground
      WakelockPlus.enable();
    }
  }

  // Add mute control methods
  void _toggleAudioMute() {
    setState(() {
      _isAudioMuted = !_isAudioMuted;
    });
    agora.setMicEnabled(!_isAudioMuted);
  }

  void _toggleVideoMute() {
    setState(() {
      _isVideoMuted = !_isVideoMuted;
    });
    agora.setCameraEnabled(!_isVideoMuted);
  }

  void _toggleSettingsMenu() {
    setState(() {
      _showSettingsMenu = !_showSettingsMenu;
    });
  }

  // Add this widget method for settings menu
  Widget _buildSettingsMenu() {
    return Positioned(
      right: 18,
      bottom: 80, // Position above the bottom actions
      child: AnimatedOpacity(
        opacity: _showSettingsMenu ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Visibility(
          visible: _showSettingsMenu,
          child: _Glass(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black.withOpacity(0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SettingsMenuItem(
                  icon: _isAudioMuted
                      ? Icons.mic_off_rounded
                      : Icons.mic_rounded,
                  label: _isAudioMuted ? 'Unmute Audio' : 'Mute Audio',
                  isActive: _isAudioMuted,
                  onTap: _toggleAudioMute,
                ),
                const SizedBox(height: 12),
                _SettingsMenuItem(
                  icon: _isVideoMuted
                      ? Icons.videocam_off_rounded
                      : Icons.videocam_rounded,
                  label: _isVideoMuted ? 'Show Video' : 'Hide Video',
                  isActive: _isVideoMuted,
                  onTap: _toggleVideoMute,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _mmss(int total) {
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Add this helper method
  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Setting up your livestream...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Channel: ${agora.channelId ?? 'Unknown'}',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (agora.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              'Error: ${agora.lastError}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agora = GetIt.I<AgoraService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: MultiBlocListener(
        listeners: [
          // 1) Navigate out when stream ends (you already had this in BlocConsumer)
          BlocListener<LiveHostBloc, LiveHostState>(
            listenWhen: (p, c) =>
                p.isLive != c.isLive || p.endAnalytics != c.endAnalytics,
            listener: (context, state) {
              if (!state.isLive) {
                // Prefer analytics route if present
                if (state.endAnalytics != null) {
                  Navigator.of(context).pushReplacementNamed(
                    RouteNames.livestreamEnded,
                    arguments: state.endAnalytics,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Live stream has ended'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(RouteNames.home, (r) => false);
                }
              }
            },
          ),

          // 2) Gift toast when gift.sent arrives
          // BlocListener<LiveHostBloc, LiveHostState>(
          //   listenWhen: (p, c) =>
          //       p.lastGift != c.lastGift && c.lastGift != null,
          //   listener: (context, state) {
          //     final g = state.lastGift!;
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       SnackBar(
          //         content: Text(
          //           '${g.from} sent “${g.giftName}” (${g.coins} coins)',
          //         ),
          //         behavior: SnackBarBehavior.floating,
          //         duration: const Duration(seconds: 2),
          //       ),
          //     );
          //   },
          // ),
        ],
        child: BlocBuilder<LiveHostBloc, LiveHostState>(
          builder: (context, state) {
            return Stack(
              children: [
                // Camera preview
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: agora,
                    builder: (_, __) {
                      return Builder(
                        builder: (context) {
                          if (!agora.joined) {
                            return _buildLoadingState();
                          }

                          final hasGuestInBloc = context
                              .select<LiveHostBloc, bool>(
                                (b) => b.state.activeGuestUuid != null,
                              );

                          final hasRemoteUid =
                              agora.primaryRemoteUid.value != null;
                          final remoteHasVideo = agora.remoteHasVideo;

                          debugPrint(
                            '🎥 Video State - Guest in BLoC: $hasGuestInBloc, '
                            'Remote UID: $hasRemoteUid, '
                            'Remote has video: $remoteHasVideo',
                          );

                          if (!hasGuestInBloc || !hasRemoteUid) {
                            // Single host view - full screen with elegant overlay
                            return Stack(
                              children: [
                                // Full screen host video
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.zero,
                                    child: agora.localPreview(),
                                  ),
                                ),
                                // Elegant gradient overlay
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.1),
                                          Colors.black.withOpacity(0.3),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          // Modern two-up layout with host and guest
                          return Stack(
                            children: [
                              // Host video - main content (larger)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                bottom: 0,
                                // Host takes 65% of screen
                                child: _buildHostVideoWithOverlay(),
                              ),

                              // Guest video - floating panel (smaller)
                              Positioned(
                                right: 16,
                                bottom: 100, // Position above bottom actions
                                width:
                                    MediaQuery.of(context).size.width *
                                    0.40, // 35% of screen width
                                height:
                                    MediaQuery.of(context).size.width *
                                    0.40 *
                                    1.77, // Maintain 16:9 aspect
                                child: _buildGuestVideoFloatingPanel(),
                              ),

                              // Connection status indicator
                              if (!remoteHasVideo)
                                Positioned(
                                  right: 16,
                                  bottom:
                                      100 +
                                      MediaQuery.of(context).size.width *
                                          0.35 *
                                          1.77 +
                                      8,
                                  child: _buildConnectionStatus(),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),

                // ===== Top Bar (fixed alignment) =====
                // ===== Top header (single tight glass bar) =====
                Positioned(
                  left: 12,
                  right: 12,
                  top: MediaQuery.of(context).padding.top + 8,
                  child: _HeaderBar(
                    hostName: widget.hostName,
                    hostBadge: widget.hostBadge,
                    avatarUrl: widget.avatarUrl,
                    timeText: _mmss(state.elapsedSeconds),
                    viewersText: _formatViewers(state.viewers),
                    onEnd: () => context.read<LiveHostBloc>().add(EndPressed()),
                  ),
                ),

                // Dim layer when paused
                if (state.isPaused)
                  Positioned.fill(
                    child: Container(color: Colors.black.withOpacity(0.55)),
                  ),

                // Topic chip
                Positioned(
                  top: 92,
                  left: 12,
                  right: 12,
                  child: _Glass(
                    radius: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      widget.topic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),

                // Join Request card
                if (state.pendingRequest != null && !state.isPaused)
                  Positioned(
                    top: 120,
                    left: 16,
                    right: 16,
                    child: _JoinRequestCard(
                      req: state.pendingRequest!,
                      onAccept: () => context.read<LiveHostBloc>().add(
                        AcceptJoinRequest(state.pendingRequest!.id),
                      ),
                      onDecline: () => context.read<LiveHostBloc>().add(
                        DeclineJoinRequest(state.pendingRequest!.id),
                      ),
                    ),
                  ),

                // Chat overlay (stable wrapping + spacing)
                // Enhanced Chat overlay with input
                if (state.chatVisible && !state.isPaused)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 135,
                    child: _HostChatWidget(
                      messages: state.messages,
                      onSendMessage: (text) {
                        context.read<LiveHostBloc>().add(SendChatMessage(text));
                      },
                    ),
                  ),
                // Bottom actions
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: SafeArea(
                    child: _BottomActions(
                      isPaused: state.isPaused,
                      onPause: () =>
                          context.read<LiveHostBloc>().add(TogglePause()),
                      onChatToggle: () => context.read<LiveHostBloc>().add(
                        ToggleChatVisibility(),
                      ),
                      onGifts: () => _toast(context, 'Gifts'),
                      onViewers: () {
                        final tracker = sl<LiveSessionTracker>();
                        // Numeric for Pusher channels:
                        final numericId = tracker.current!.livestreamId;
                        // REST param — use uuid if you track it, else the same numeric id is fine:
                        final restParam = '${tracker.current!.livestreamId}';

                        registerParticipantsScope(
                          livestreamIdNumeric: numericId,
                          livestreamParam: restParam,
                        );

                        Navigator.pushNamed(context, RouteNames.listViewers);
                      },
                      onPremium: () =>
                          Navigator.pushNamed(context, RouteNames.profile_view),
                      onSettings: _toggleSettingsMenu,
                    ),
                  ),
                ),
                // Settings Menu - NEW
                _buildSettingsMenu(),
                // Paused overlay
                if (state.isPaused)
                  _PausedOverlay(
                    onResume: () =>
                        context.read<LiveHostBloc>().add(TogglePause()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static void _toast(BuildContext c, String title) {
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(
        content: Text('$title coming soon'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatViewers(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }

  Widget _buildHostVideoWithOverlay() {
    return Stack(
      children: [
        // Host video
        ClipRRect(borderRadius: BorderRadius.zero, child: agora.localPreview()),
        // Elegant gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.2)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestVideoFloatingPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Stack(
        children: [
          // Main guest video container
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Guest video
                  agora.primaryRemoteView(),

                  // Shimmer effect overlay when connecting
                  if (!agora.remoteHasVideo)
                    Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF6A00),
                              ),
                              strokeWidth: 2,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connecting...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Guest label
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_rounded,
                    color: Colors.orangeAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'GUEST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Audio indicator
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                color: Colors.greenAccent,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: agora.remoteHasVideo
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            agora.remoteHasVideo ? 'Live' : 'Connecting...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== Visual helpers =====
class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  const _Glass({
    required this.child,
    required this.padding,
    this.radius = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ClipRect(
        // <-- hard clip the blur area
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (color ?? Colors.black.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Glass_Trans extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  const _Glass_Trans({
    required this.child,
    required this.padding,
    this.radius = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        child: child,
        decoration: BoxDecoration(
          color: (color ?? Colors.black.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// ===== Chat List (stable wrapping) =====
class _ChatList extends StatefulWidget {
  final List messages; // List<LiveChatMessage>
  const _ChatList({required this.messages, super.key});
  @override
  State<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<_ChatList> {
  final _ctrl = ScrollController();

  @override
  void didUpdateWidget(covariant _ChatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ctrl.hasClients) {
          _ctrl.animateTo(
            _ctrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fixed, predictable height that still wraps long lines.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64, maxHeight: 180),
      child: ListView.builder(
        controller: _ctrl,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: widget.messages.length,
        itemBuilder: (_, i) {
          final m = widget.messages[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  // <- enforce a default style so nothing renders “invisible”
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.25,
                ),
                children: [
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: SizedBox(width: 0), // keeps baseline stable
                  ),
                  TextSpan(
                    text: '${m.handle}  ',
                    style: const TextStyle(
                      color: Color(0xFF58B5FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: m.text),
                ],
              ),
              softWrap: true,
              textAlign: TextAlign.left,
            ),
          );
        },
      ),
    );
  }
}

/// ===== Bottom Actions =====
class _BottomActions extends StatelessWidget {
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onChatToggle;
  final VoidCallback onViewers;
  final VoidCallback onGifts;
  final VoidCallback onPremium;
  final VoidCallback onSettings; // NEW

  const _BottomActions({
    required this.isPaused,
    required this.onPause,
    required this.onChatToggle,
    required this.onViewers,
    required this.onGifts,
    required this.onPremium,
    required this.onSettings, // NEW
  });

  Widget _item(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isSettings = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: isSettings ? 44 : 48, // Slightly smaller for settings
            height: isSettings ? 44 : 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isSettings ? 20 : 24, // Slightly smaller icon for settings
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _item(Icons.chat_bubble_rounded, 'Chat', onChatToggle),
          _item(Icons.visibility_rounded, 'Viewers', onViewers),

          InkWell(
            onTap: onPause,
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isPaused ? 'Resume' : 'Pause',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),

          _item(Icons.card_giftcard_rounded, 'Gifts', onGifts),
          _item(Icons.card_giftcard_rounded, 'Premiums', onPremium),
          _item(
            Icons.settings_rounded,
            'Settings',
            onSettings,
            isSettings: true,
          ), // NEW
        ],
      ),
    );
  }
}

// Add this new widget for settings menu items
class _SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SettingsMenuItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.orangeAccent : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.orangeAccent : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== Request Card =====
class _JoinRequestCard extends StatelessWidget {
  final LiveJoinRequest req;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _JoinRequestCard({
    required this.req,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      color: const Color(0xFF070B12).withOpacity(.92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    (req.avatarUrl.isNotEmpty &&
                        req.avatarUrl.startsWith('http'))
                    ? NetworkImage(req.avatarUrl)
                    : const AssetImage('assets/images/logo.png')
                          as ImageProvider,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2ECC71),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Ambassador',
                          style: TextStyle(
                            color: Color(0xFF7ED957),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'wants to join your livestream',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CTAButton(
                  label: 'Accept',
                  bg: const Color(0xFF2ECC71),
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CTAButton(
                  label: 'Decline',
                  bg: const Color(0xFFE53935),
                  onTap: onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  final String label;
  final Color bg;
  final VoidCallback onTap;
  const _CTAButton({
    required this.label,
    required this.bg,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

/// ===== Paused Overlay =====
class _PausedOverlay extends StatelessWidget {
  final VoidCallback onResume;
  const _PausedOverlay({required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pause_circle_filled_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 8),
            const Text(
              'Stream Paused',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.0),
              child: Text(
                'Viewers will be notified when you resume your stream.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onResume,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6A00),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6A00).withOpacity(.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Resume Stream',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final String hostName;
  final String hostBadge;
  final String timeText;
  final String viewersText;
  final String? avatarUrl; // NEW
  final VoidCallback onEnd;

  const _HeaderBar({
    required this.hostName,
    required this.hostBadge,
    required this.timeText,
    required this.viewersText,
    required this.onEnd,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final ImageProvider img =
        (avatarUrl != null && avatarUrl!.startsWith('http'))
        ? NetworkImage(avatarUrl!)
        : const AssetImage('assets/images/logo.png');

    return _Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CircleAvatar(radius: 14, backgroundImage: img),
          ),
          const SizedBox(width: 8),
          // host name + badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hostName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              _Badge(text: hostBadge),
            ],
          ),
          const SizedBox(width: 10),

          // LIVE dot + timer + viewers (nudged to align with text cap-height)
          const Padding(padding: EdgeInsets.only(top: 2), child: _LiveDot()),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              timeText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.remove_red_eye_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              viewersText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const Spacer(),

          // End button (inside the SAME glass, top aligned)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(.65),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'End',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== Enhanced Host Chat Widget =====
class _HostChatWidget extends StatefulWidget {
  final List<LiveChatMessage> messages;
  final Function(String) onSendMessage;

  const _HostChatWidget({required this.messages, required this.onSendMessage});

  @override
  State<_HostChatWidget> createState() => _HostChatWidgetState();
}

class _HostChatWidgetState extends State<_HostChatWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showEmojiPicker = false;

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _textController.clear();
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = false);
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _insertEmoji(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _textController.text = newText;
    _textController.selection = selection.copyWith(
      baseOffset: selection.start + emoji.length,
      extentOffset: selection.start + emoji.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chat messages list
        _Glass(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: _ChatList(messages: widget.messages),
        ),

        const SizedBox(height: 8),

        // Chat input area
        _Glass(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              // Emoji picker button
              IconButton(
                icon: Icon(
                  _showEmojiPicker
                      ? Icons.keyboard_rounded
                      : Icons.emoji_emotions_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
                onPressed: _toggleEmojiPicker,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),

              const SizedBox(width: 8),

              // Text field
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Send a message...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: 1,
                ),
              ),

              const SizedBox(width: 8),

              // Send button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6A00),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  color: Colors.white,
                  onPressed: _sendMessage,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),

        // Emoji picker (conditional)
        if (_showEmojiPicker) ...[
          const SizedBox(height: 8),
          _Glass(
            radius: 16,
            padding: const EdgeInsets.all(12),
            child: _EmojiGrid(onEmojiSelected: _insertEmoji),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

/// ===== Simple Emoji Grid =====
class _EmojiGrid extends StatelessWidget {
  final Function(String) onEmojiSelected;

  final List<String> emojis = [
    '😂',
    '😍',
    '🥰',
    '😭',
    '😊',
    '👍',
    '❤️',
    '🔥',
    '🙏',
    '😎',
    '🎉',
    '💯',
    '🤔',
    '😢',
    '👏',
    '🙌',
    '😘',
    '🤣',
    '😅',
    '😡',
    '👀',
    '✨',
    '💕',
    '🎶',
  ];

  _EmojiGrid({required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => onEmojiSelected(emojis[index]),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.1),
            ),
            child: Center(
              child: Text(emojis[index], style: const TextStyle(fontSize: 20)),
            ),
          ),
        );
      },
    );
  }
}
