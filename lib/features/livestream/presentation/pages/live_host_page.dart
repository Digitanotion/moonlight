import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/livestream/domain/entities/live_join_request.dart';
import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';

class LiveHostPage extends StatefulWidget {
  final String hostName;
  final String hostBadge; // e.g., "Superstar"
  final String topic; // e.g., "Talking about Mental Health"

  const LiveHostPage({
    super.key,
    required this.hostName,
    required this.hostBadge,
    required this.topic,
  });

  @override
  State<LiveHostPage> createState() => _LiveHostPageState();
}

class _LiveHostPageState extends State<LiveHostPage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  bool _initErr = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
    context.read<LiveHostBloc>().add(LiveStarted(widget.topic));
  }

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      _controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      _initErr = true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _mmss(int total) {
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<LiveHostBloc, LiveHostState>(
        listenWhen: (p, c) => p.isLive && !c.isLive,
        listener: (context, state) {
          if (!state.isLive && mounted) Navigator.of(context).pop();
        },
        builder: (context, state) {
          return Stack(
            children: [
              // Camera preview
              Positioned.fill(
                child: _controller == null
                    ? const SizedBox.shrink()
                    : (!_initErr && _controller!.value.isInitialized)
                    ? CameraPreview(_controller!)
                    : const Center(
                        child: Text(
                          'Camera unavailable',
                          style: TextStyle(color: Colors.white),
                        ),
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
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
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
              if (state.chatVisible && !state.isPaused)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 135,
                  child: _Glass(
                    radius: 18,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: _ChatList(messages: state.messages),
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
                    onViewers: () =>
                        Navigator.pushNamed(context, RouteNames.liveViewer),
                    onPremium: () => _toast(context, 'Premium'),
                  ),
                ),
              ),

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

  const _BottomActions({
    required this.isPaused,
    required this.onPause,
    required this.onChatToggle,
    required this.onViewers,
    required this.onGifts,
    required this.onPremium,
  });

  Widget _item(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(icon, color: Colors.white),
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
          _item(Icons.workspace_premium_rounded, 'Premium', onPremium),
        ],
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
                backgroundImage: AssetImage(req.avatarUrl),
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
  final VoidCallback onEnd;

  const _HeaderBar({
    required this.hostName,
    required this.hostBadge,
    required this.timeText,
    required this.viewersText,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // top-align all items
        children: [
          // avatar
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: CircleAvatar(
              radius: 14,
              backgroundImage: AssetImage('assets/avatar_placeholder.png'),
            ),
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
