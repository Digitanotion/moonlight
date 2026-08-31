// lib/features/video_call/presentation/pages/active_call_screen.dart
import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/video_call/data/models/video_call_session_model.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';

String _firstName(String? full) {
  final t = (full ?? '').trim();
  if (t.isEmpty) return 'Unknown';
  return t.split(RegExp(r'\s+')).first;
}

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  bool _controlsVisible = true;

  @override
  Widget build(BuildContext context) {
    final agora = context.read<VideoCallBloc>().agora;
    final bloc = context.read<VideoCallBloc>();

    return BlocConsumer<VideoCallBloc, VideoCallState>(
      listenWhen: (prev, curr) => prev.phase != curr.phase,
      listener: (context, state) {
        if (state.phase == VideoCallPhase.ended) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: const CallSummaryScreen(),
              ),
            ),
          );
        } else if (state.phase == VideoCallPhase.idle) {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final session = state.session;
        // Each side shows the OTHER person — caller sees the callee,
        // callee sees the caller.
        final VideoCallUserSummary? otherParty =
            state.isCaller ? session?.callee : session?.caller;
        final name = _firstName(otherParty?.displayName);
        final avatarUrl = otherParty?.avatarUrl;
        final showTimer = state.isCaller && state.countdownEndsAt != null;

        return PopScope(
          canPop: false, // intercept every exit path ourselves
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            // Same reasoning as the other two call screens: VideoCallBloc
            // is a global singleton, so leaving an ACTIVE call via the
            // back button must properly end the call server-side (not
            // just leave it stuck), and reset the bloc to idle either way.
            if (bloc.state.phase == VideoCallPhase.active) {
              bloc.add(CallEndRequested(reason: 'left_screen'));
            } else if (bloc.state.phase != VideoCallPhase.idle) {
              bloc.add(CallDismissed());
            }
            Navigator.of(context).pop();
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: GestureDetector(
              onTap: () => setState(() => _controlsVisible = !_controlsVisible),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Remote video, full screen (or hero backdrop) ──────
                  ListenableBuilder(
                    listenable: agora,
                    builder: (context, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: agora.remoteHasVideo,
                        builder: (context, hasVideo, _) {
                          if (!hasVideo) {
                            return _HeroBackdrop(
                              name: name,
                              avatarUrl: avatarUrl,
                              status: (state.isPaused || state.localMediaDown)
                                  ? 'Reconnecting…'
                                  : 'Connecting…',
                            );
                          }
                          return agora.remoteView();
                        },
                      );
                    },
                  ),

                  // Soft top/bottom scrims so chrome stays legible over video.
                  const _EdgeScrims(),

                  // ── Local preview ─────────────────────────────────────
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 64,
                    right: 14,
                    child: AnimatedSlide(
                      offset: _controlsVisible ? Offset.zero : const Offset(0, -0.15),
                      duration: const Duration(milliseconds: 220),
                      child: AnimatedOpacity(
                        opacity: _controlsVisible ? 1 : 0.35,
                        duration: const Duration(milliseconds: 220),
                        child: Container(
                          width: 96,
                          height: 132,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: agora.localPreview(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Top chrome: identity + timer + report ─────────────
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 40),
                                Expanded(
                                  child: Center(
                                    child: showTimer
                                        ? _CountdownPill(
                                            endsAt: state.countdownEndsAt!,
                                            paused: state.isPaused,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                _GlassIconButton(
                                  icon: Icons.flag_outlined,
                                  onTap: () => _showReportSheet(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _CallerIdentity(
                                name: name,
                                avatarUrl: avatarUrl,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Network-drop banner (#3) / extend prompt ──────────
                  if (state.isPaused || state.localMediaDown)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 128,
                      left: 20,
                      right: 20,
                      child: _ReconnectingBanner(
                        // The caller's freeze is authoritative & billed-safe;
                        // the callee's is just "we can't see them right now".
                        billed: state.isCaller,
                      ),
                    ),
                  if (state.showExtendPrompt &&
                      !state.isPaused &&
                      !state.localMediaDown &&
                      state.isCaller)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 128,
                      left: 20,
                      right: 20,
                      child: _ExtendBanner(
                        loading: state.actionLoading,
                        onExtend: (minutes) => context
                            .read<VideoCallBloc>()
                            .add(CallExtendRequested(minutes)),
                      ),
                    ),

                  // ── Bottom control bar ───────────────────────────────
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListenableBuilder(
                                      listenable: agora,
                                      builder: (context, _) => _ControlButton(
                                        icon: agora.isMicEnabled
                                            ? Icons.mic_rounded
                                            : Icons.mic_off_rounded,
                                        active: agora.isMicEnabled,
                                        onTap: () => agora
                                            .setMicEnabled(!agora.isMicEnabled),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ListenableBuilder(
                                      listenable: agora,
                                      builder: (context, _) => _ControlButton(
                                        icon: agora.isCameraEnabled
                                            ? Icons.videocam_rounded
                                            : Icons.videocam_off_rounded,
                                        active: agora.isCameraEnabled,
                                        onTap: () => agora.setCameraEnabled(
                                          !agora.isCameraEnabled,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _ControlButton(
                                      icon: Icons.flip_camera_ios_rounded,
                                      active: true,
                                      onTap: agora.switchCamera,
                                    ),
                                    const SizedBox(width: 14),
                                    _EndCallButton(
                                      onTap: () => context
                                          .read<VideoCallBloc>()
                                          .add(CallEndRequested(reason: null)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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

  void _showReportSheet(BuildContext context) {
    final bloc = context.read<VideoCallBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report this call',
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              for (final reason in const [
                'inappropriate_behavior',
                'harassment',
                'nudity_or_sexual_content',
                'scam_or_fraud',
                'other',
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    reason
                        .replaceAll('_', ' ')
                        .split(' ')
                        .map((w) => w[0].toUpperCase() + w.substring(1))
                        .join(' '),
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                  onTap: () {
                    bloc.add(CallReportRequested(reason: reason));
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero backdrop shown before the remote video arrives ─────────────────
class _HeroBackdrop extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String status;
  const _HeroBackdrop({
    required this.name,
    required this.avatarUrl,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasAvatar)
          CachedNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover)
        else
          Container(color: AppColors.navy),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(color: Colors.black.withOpacity(0.55)),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 2,
                  ),
                ),
                child: _Avatar(url: avatarUrl, radius: 52, name: name),
              ),
              const SizedBox(height: 18),
              Text(
                name,
                style: AppTextStyles.headlineLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                status,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EdgeScrims extends StatelessWidget {
  const _EdgeScrims();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.45), Colors.transparent],
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.5), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double radius;
  final String name;
  const _Avatar({required this.url, required this.radius, required this.name});

  @override
  Widget build(BuildContext context) {
    final has = url != null && url!.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.card,
      backgroundImage: has ? CachedNetworkImageProvider(url!) : null,
      child: has
          ? null
          : Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _CallerIdentity extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  const _CallerIdentity({required this.name, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(url: avatarUrl, radius: 16, name: name),
        const SizedBox(width: 10),
        Text(
          name,
          style: AppTextStyles.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _CountdownPill extends StatefulWidget {
  final DateTime endsAt;
  final bool paused;
  const _CountdownPill({required this.endsAt, this.paused = false});

  @override
  State<_CountdownPill> createState() => _CountdownPillState();
}

class _CountdownPillState extends State<_CountdownPill> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _CountdownPill old) {
    super.didUpdateWidget(old);
    if (old.paused != widget.paused) _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (widget.paused) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(DateTime.now()).inSeconds;
    final safe = remaining < 0 ? 0 : remaining;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    final urgent = safe <= 30 && !widget.paused;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (urgent ? AppColors.textRed : Colors.white).withOpacity(
              urgent ? 0.85 : 0.14,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: urgent
                  ? AppColors.textRed
                  : Colors.white.withOpacity(0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.paused
                    ? Icons.pause_rounded
                    : Icons.schedule_rounded,
                color: Colors.white,
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                widget.paused
                    ? 'Paused'
                    : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndCallButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EndCallButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textRed,
          boxShadow: [
            BoxShadow(
              color: AppColors.textRed.withOpacity(0.45),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.call_end_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

class _ReconnectingBanner extends StatelessWidget {
  final bool billed;
  const _ReconnectingBanner({this.billed = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  billed
                      ? 'Connection lost — reconnecting. Your time is paused.'
                      : 'Connection lost — reconnecting…',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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

class _ExtendBanner extends StatelessWidget {
  final bool loading;
  final void Function(int minutes) onExtend;
  const _ExtendBanner({required this.loading, required this.onExtend});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -20),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary_.withOpacity(0.95),
              AppColors.primary2.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary_.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_filled_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your call is ending in 30 seconds!',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // GestureDetector(
            //   onTap: loading ? null : () => onExtend(1),
            //   child: Container(
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 14,
            //       vertical: 8,
            //     ),
            //     decoration: BoxDecoration(
            //       color: Colors.white,
            //       borderRadius: BorderRadius.circular(10),
            //     ),
            //     child: loading
            //         ? const SizedBox(
            //             width: 14,
            //             height: 14,
            //             child: CircularProgressIndicator(strokeWidth: 2),
            //           )
            //         : Text(
            //             'Add time',
            //             style: AppTextStyles.caption.copyWith(
            //               color: AppColors.primary_,
            //               fontWeight: FontWeight.w800,
            //             ),
            //           ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? Colors.white.withOpacity(0.16)
              : Colors.white.withOpacity(0.92),
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : AppColors.dark,
          size: 22,
        ),
      ),
    );
  }
}

// ── Call summary screen, shown right after end() resolves ────────────────

class CallSummaryScreen extends StatelessWidget {
  const CallSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoCallBloc, VideoCallState>(
      builder: (context, state) {
        final session = state.session;
        final settled = session?.totalCoinsSettled ?? 0;
        final refunded = session?.totalCoinsRefunded ?? 0;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            // Summary screen is always safe to reset — the call has
            // already fully ended by the time this screen shows.
            context.read<VideoCallBloc>().add(CallDismissed());
            Navigator.of(context).pop();
          },
          child: Scaffold(
            backgroundColor: AppColors.dark,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.navy, AppColors.bgBottom],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentGreen.withOpacity(0.15),
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: AppColors.accentGreen,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Call ended',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (settled > 0)
                        _summaryRow('Coins spent', '$settled', AppColors.primary2),
                      if (refunded > 0)
                        _summaryRow(
                          'Coins refunded',
                          '$refunded',
                          AppColors.accentGreen,
                        ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary_,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            context.read<VideoCallBloc>().add(CallDismissed());
                            // Popping all the way to root was correct for a
                            // normal directory/profile call, but destroyed
                            // the callee's own LiveHostPage (and, via its
                            // bloc's close(), genuinely ended her livestream
                            // on the backend) whenever the call happened
                            // while she was live. Just pop back to whatever
                            // she was on before in that case — her stream
                            // is still there underneath, exactly as it
                            // should be.
                            if (session?.initiatedFrom == 'livestream') {
                              Navigator.of(context).pop();
                            } else {
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            }
                          },
                          child: Text(
                            'Done',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(color: Colors.white70),
          ),
          Text(
            '$value coins',
            style: AppTextStyles.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}