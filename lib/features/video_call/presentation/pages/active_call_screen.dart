// lib/features/video_call/presentation/pages/active_call_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';

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
        final otherParty = session?.caller ?? session?.callee;

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
                  // ── Remote video, full screen ─────────────────────────
                  ListenableBuilder(
                    listenable: agora,
                    builder: (context, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: agora.remoteHasVideo,
                        builder: (context, hasVideo, _) {
                          if (!hasVideo) {
                            return _connectingPlaceholder(otherParty?.displayName);
                          }
                          return agora.remoteView();
                        },
                      );
                    },
                  ),

                  // ── Local preview bubble ───────────────────────────────
                  Positioned(
                    top: 60,
                    right: 16,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 100,
                        height: 148,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: agora.localPreview(),
                        ),
                      ),
                    ),
                  ),

                  // ── Top bar: name + countdown ──────────────────────────
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  otherParty?.displayName ?? '',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: Colors.white,
                                    shadows: [
                                      const Shadow(
                                        color: Colors.black54,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (session?.endsAt != null)
                              _CountdownPill(endsAt: session!.endsAt!),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Extend prompt (doc 1C: 30s remaining) ──────────────
                  if (state.showExtendPrompt)
                    Positioned(
                      top: 110,
                      left: 20,
                      right: 20,
                      child: _ExtendBanner(
                        loading: state.actionLoading,
                        onExtend: (minutes) => context
                            .read<VideoCallBloc>()
                            .add(CallExtendRequested(minutes)),
                      ),
                    ),

                  // ── Bottom controls ─────────────────────────────────────
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 28, top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ListenableBuilder(
                                listenable: agora,
                                builder: (context, _) => _ControlButton(
                                  icon: agora.isMicEnabled
                                      ? Icons.mic_rounded
                                      : Icons.mic_off_rounded,
                                  active: agora.isMicEnabled,
                                  onTap: () =>
                                      agora.setMicEnabled(!agora.isMicEnabled),
                                ),
                              ),
                              ListenableBuilder(
                                listenable: agora,
                                builder: (context, _) => _ControlButton(
                                  icon: agora.isCameraEnabled
                                      ? Icons.videocam_rounded
                                      : Icons.videocam_off_rounded,
                                  active: agora.isCameraEnabled,
                                  onTap: () => agora
                                      .setCameraEnabled(!agora.isCameraEnabled),
                                ),
                              ),
                              _ControlButton(
                                icon: Icons.cameraswitch_rounded,
                                active: true,
                                onTap: agora.switchCamera,
                              ),
                              _ControlButton(
                                icon: Icons.flag_rounded,
                                active: true,
                                onTap: () => _showReportSheet(context),
                              ),
                              GestureDetector(
                                onTap: () => context
                                    .read<VideoCallBloc>()
                                    .add(CallEndRequested(reason: null)),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.textRed,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.textRed.withOpacity(0.5),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.call_end_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
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

  Widget _connectingPlaceholder(String? name) {
    return Container(
      color: AppColors.dark,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary2),
          const SizedBox(height: 16),
          Text(
            name != null ? 'Connecting to $name...' : 'Connecting...',
            style: AppTextStyles.body.copyWith(color: Colors.white70),
          ),
        ],
      ),
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

class _CountdownPill extends StatefulWidget {
  final DateTime endsAt;
  const _CountdownPill({required this.endsAt});

  @override
  State<_CountdownPill> createState() => _CountdownPillState();
}

class _CountdownPillState extends State<_CountdownPill> {
  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(DateTime.now()).inSeconds;
    final safe = remaining < 0 ? 0 : remaining;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    final urgent = safe <= 30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (urgent ? AppColors.textRed : Colors.black).withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: urgent ? AppColors.textRed : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? Colors.white.withOpacity(0.15) : AppColors.textRed,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
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
                            Navigator.of(context).popUntil((r) => r.isFirst);
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