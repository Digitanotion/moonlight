// lib/features/video_call/presentation/pages/incoming_call_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moonlight/core/services/ringtone_player.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';
import 'package:moonlight/features/video_call/presentation/widgets/incoming_call_banner.dart';
import 'package:moonlight/features/video_call/presentation/pages/active_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    // Hide IncomingCallBanner while this full-screen variant (reached by
    // explicitly tapping a call notification/CallResumeFromNotification)
    // is showing — both react to the same bloc phase, so without this
    // they'd render simultaneously for the same call.
    IncomingCallBanner.suppressed.value = true;
  }

  @override
  void dispose() {
    IncomingCallBanner.suppressed.value = false;
    _ringController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<VideoCallBloc>();
    return BlocConsumer<VideoCallBloc, VideoCallState>(
      listenWhen: (prev, curr) => prev.phase != curr.phase,
      listener: (context, state) {
        if (state.phase == VideoCallPhase.active) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: const ActiveCallScreen(),
              ),
            ),
          );
        } else if (state.phase == VideoCallPhase.idle) {
          // Rejected, or the call vanished (timeout/cancelled by caller)
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final caller = state.session?.caller;
        final name = caller?.displayName ?? 'Unknown';
        final avatarUrl = caller?.avatarUrl;

        return PopScope(
          canPop: false, // intercept every exit path ourselves
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            // Same reasoning as OutgoingCallScreen: VideoCallBloc is a
            // global singleton now, so leaving this screen via ANY route
            // must force-reset its phase, or it stays stuck "busy" and
            // silently ignores every future incoming call.
            if (bloc.state.phase != VideoCallPhase.idle) {
              final uuid = bloc.state.session?.uuid;
              if (uuid != null) {
                bloc.add(CallRejectRequested(uuid));
              } else {
                bloc.add(CallDismissed());
              }
            }
            Navigator.of(context).pop();
          },
          child: Scaffold(
            backgroundColor: AppColors.dark,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // ── Blurred backdrop of the caller's photo ──────────────
                if (avatarUrl != null && avatarUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: AppColors.dark),
                  ),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.navy.withOpacity(0.55),
                            AppColors.bgBottom.withOpacity(0.92),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Content ──────────────────────────────────────────────
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        'Incoming video call',
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white.withOpacity(0.75),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(flex: 2),

                      // ── Avatar with expanding ring pulses ─────────────
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _ringController,
                              builder: (context, _) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: List.generate(3, (i) {
                                    final delay = i * 0.33;
                                    var t = (_ringController.value + delay) % 1.0;
                                    return Opacity(
                                      opacity: (1 - t).clamp(0.0, 1.0) * 0.5,
                                      child: Container(
                                        width: 140 + (t * 100),
                                        height: 140 + (t * 100),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.primary2,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                            ScaleTransition(
                              scale: Tween(begin: 0.97, end: 1.03).animate(
                                CurvedAnimation(
                                  parent: _pulseController,
                                  curve: Curves.easeInOut,
                                ),
                              ),
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.9),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary2.withOpacity(0.5),
                                      blurRadius: 30,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              _avatarFallback(name),
                                        )
                                      : _avatarFallback(name),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),
                      Text(
                        name,
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'wants to video call you',
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ),

                      const Spacer(flex: 3),

                      // ── Actions ────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 24,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _CallActionButton(
                              icon: Icons.call_end_rounded,
                              color: AppColors.textRed,
                              label: 'Decline',
                              loading: state.actionLoading,
                              onTap: () {
                                // Unconditional, regardless of whether
                                // session data actually loaded for this
                                // screen (e.g. opened via notification for
                                // a call that had already resolved server
                                // -side by the time this screen appeared —
                                // confirmed by testing to leave session
                                // null here) — the user tapped Decline,
                                // ringtone stops, full stop, no exceptions.
                                // main.dart's global idle-phase handler is
                                // the real backstop for this regardless,
                                // but don't wait on that async round trip
                                // when we can do it synchronously right now.
                                RingtonePlayer().stop();
                                final uuid = state.session?.uuid;
                                if (uuid != null) {
                                  context
                                      .read<VideoCallBloc>()
                                      .add(CallRejectRequested(uuid));
                                } else {
                                  // No session to reject — still force
                                  // this screen closed rather than leaving
                                  // the user stuck on a dead-end Decline
                                  // button that visibly does nothing.
                                  context.read<VideoCallBloc>().add(CallDismissed());
                                }
                              },
                            ),
                            _CallActionButton(
                              icon: Icons.videocam_rounded,
                              color: AppColors.accentGreen,
                              label: 'Accept',
                              loading: state.actionLoading,
                              onTap: () {
                                final uuid = state.session?.uuid;
                                if (uuid != null) {
                                  context
                                      .read<VideoCallBloc>()
                                      .add(CallAcceptRequested(uuid));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _avatarFallback(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: AppColors.card,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.headlineLarge.copyWith(
          color: Colors.white,
          fontSize: 48,
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: loading ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}