// lib/features/video_call/presentation/pages/outgoing_call_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';
import 'package:moonlight/features/video_call/presentation/pages/active_call_screen.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String calleeUserSlug;
  final String calleeDisplayName;
  final String? calleeAvatarUrl;
  final String initiatedFrom; // directory|profile|livestream
  final int? livestreamId;
  final int initialMinutes;

  const OutgoingCallScreen({
    super.key,
    required this.calleeUserSlug,
    required this.calleeDisplayName,
    this.calleeAvatarUrl,
    required this.initiatedFrom,
    this.livestreamId,
    this.initialMinutes = 1,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _dialed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reads the single app-wide VideoCallBloc (provided once near app root
    // — see main.dart wiring notes). Never create a second instance here:
    // that bloc is also the one listening for incoming-call/accepted
    // events, and a second instance would double-react to the same event.
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
        } else if (state.phase == VideoCallPhase.idle && _dialed && state.error == null) {
          // Clean idle transition (rejected, no answer) — safe to
          // auto-pop. If state.error is set (e.g. "already on another
          // call", insufficient coins), DON'T auto-pop — the error needs
          // to actually stay visible long enough to read, and the user
          // dismisses manually via the decline button below. This
          // condition was accidentally dropped during an earlier full-file
          // rewrite (the PopScope addition) — restoring it here.
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        if (!_dialed) {
          _dialed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            bloc.add(
              CallInitiateRequested(
                calleeUserSlug: widget.calleeUserSlug,
                minutes: widget.initialMinutes,
                initiatedFrom: widget.initiatedFrom,
                livestreamId: widget.livestreamId,
              ),
            );
          });
        }

        return PopScope(
          canPop: false, // intercept every exit path ourselves
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            // Since VideoCallBloc is now a global singleton (not a
            // per-screen instance), leaving this screen via ANY route
            // (back button, swipe gesture, OS back) must force-reset its
            // phase back to idle — otherwise the bloc stays stuck
            // "busy" and silently ignores every future incoming call
            // for the rest of the app session (see the "already busy"
            // bug this fixes).
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
                if (widget.calleeAvatarUrl != null &&
                    widget.calleeAvatarUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: widget.calleeAvatarUrl!,
                    fit: BoxFit.cover,
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
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        _statusLabel(state),
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white.withOpacity(0.75),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(flex: 2),
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
                            child:
                                (widget.calleeAvatarUrl != null &&
                                    widget.calleeAvatarUrl!.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: widget.calleeAvatarUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _avatarFallback(),
                                  )
                                : _avatarFallback(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        widget.calleeDisplayName,
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            state.error!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textRed,
                            ),
                          ),
                        ),
                      const Spacer(flex: 3),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: GestureDetector(
                          onTap: () {
                            final uuid = state.session?.uuid;
                            if (uuid != null) {
                              // reject() is callee-only on the backend
                              // (correctly — only the person being called
                              // can decline an incoming ring). The
                              // CALLER cancelling their own outgoing call
                              // before it's answered needs end(), not
                              // reject() — using reject() here was
                              // hitting a 422 ("not the recipient"),
                              // silently failing to resolve the call at
                              // all, which is why the receiver's screen
                              // never got the broadcast telling it to
                              // close.
                              bloc.add(
                                CallEndRequested(reason: 'caller_ended'),
                              );
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.textRed,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.textRed.withOpacity(0.45),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.call_end_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
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

  String _statusLabel(VideoCallState state) {
    if (state.error != null) return 'Could not connect';
    if (state.phase == VideoCallPhase.connecting) return 'Connecting...';
    return 'Calling...';
  }

  Widget _avatarFallback() {
    final name = widget.calleeDisplayName;
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