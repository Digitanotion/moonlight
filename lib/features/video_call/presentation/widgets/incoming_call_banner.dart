// lib/features/video_call/presentation/widgets/incoming_call_banner.dart
//
// App-wide persistent incoming-call banner — wraps MaterialApp's `builder`
// in main.dart, exactly like SimpleConnectionToast (see
// lib/core/widgets/connection_toast.dart), so it renders in a Stack above
// the entire Navigator: visible no matter which screen the user is
// currently on, survives navigation underneath it, and needs no
// BlocProvider ancestor since it reads VideoCallBloc straight from GetIt.
//
// Purpose-built for the foreground case. CallKit's native full-screen UI
// only auto-launches when the device is locked/screen-off (see
// main.dart's _startGlobalVideoCallListeners for the platform-behavior
// doc comment) — for an already-active app, this banner is the entire
// incoming-call experience: it appears the instant the bloc reaches
// ringingIncoming and disappears the instant it leaves that phase
// (accepted, declined, ended by the other party, or timed out). Unlike a
// one-shot full-screen takeover, it also stays reachable if the user
// switches to another in-app screen mid-ring — that was the actual gap
// motivating this over a full-screen push: nothing to return to once
// dismissed.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/ringtone_player.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';

class IncomingCallBanner extends StatefulWidget {
  final Widget child;
  const IncomingCallBanner({super.key, required this.child});

  /// Set true while IncomingCallScreen (the full-screen variant, pushed
  /// when the user explicitly taps a call notification) is on-screen —
  /// avoids showing this banner redundantly on top of it for the exact
  /// same call. Same pattern as SimpleConnectionToast.pipActive.
  static final ValueNotifier<bool> suppressed = ValueNotifier(false);

  @override
  State<IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends State<IncomingCallBanner> {
  StreamSubscription<VideoCallState>? _sub;
  bool _visible = false;
  // Kept even after _visible flips false, so the exit animation slides
  // away showing the real caller info instead of popping empty.
  VideoCallState? _displayState;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // This widget wraps MaterialApp's builder, so it mounts on MyApp's
    // very first build — right after the bare splash frame, well before
    // background init (_initEverything in main.dart) has finished
    // registering VideoCallBloc and its dependencies in GetIt. Wait for
    // the same readiness gate the splash route itself waits on before
    // ever touching sl<VideoCallBloc>() (calling it earlier throws:
    // "VideoCallBloc is not registered inside GetIt").
    await DependencyManager.waitForAllDependencies();
    if (!mounted) return;
    final bloc = sl<VideoCallBloc>();
    _applyState(bloc.state);
    _sub = bloc.stream.listen(_applyState);
  }

  void _applyState(VideoCallState state) {
    if (!mounted) return;
    final isRinging = state.phase == VideoCallPhase.ringingIncoming;
    if (isRinging && !_visible) {
      RingtonePlayer().play();
    } else if (!isRinging && _visible) {
      RingtonePlayer().stop();
    }
    setState(() {
      _visible = isRinging;
      if (isRinging) _displayState = state;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _accept() {
    final uuid = _displayState?.session?.uuid;
    if (uuid == null) return;
    sl<VideoCallBloc>().add(CallAcceptRequested(uuid));
  }

  void _decline() {
    final uuid = _displayState?.session?.uuid;
    if (uuid == null) return;
    RingtonePlayer().stop(); // don't wait for the reject round-trip
    sl<VideoCallBloc>().add(CallRejectRequested(uuid));
  }

  @override
  Widget build(BuildContext context) {
    final caller = _displayState?.session?.caller;
    final loading = _displayState?.actionLoading ?? false;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: IncomingCallBanner.suppressed,
            builder: (context, suppressed, _) {
              final show = _visible && !suppressed;
              return IgnorePointer(
                ignoring: !show,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  offset: show ? Offset.zero : const Offset(0, -1.3),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: show ? 1 : 0,
                    child: SafeArea(
                      bottom: false,
                      child: _BannerCard(
                        name: caller?.displayName ?? 'Someone',
                        avatarUrl: caller?.avatarUrl,
                        loading: loading,
                        onAccept: _accept,
                        onDecline: _decline,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool loading;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _BannerCard({
    required this.name,
    required this.avatarUrl,
    required this.loading,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.dark.withOpacity(0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _fallbackAvatar(name),
                        )
                      : _fallbackAvatar(name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Incoming video call',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RoundButton(
                icon: Icons.call_end_rounded,
                color: AppColors.textRed,
                loading: loading,
                onTap: onDecline,
              ),
              const SizedBox(width: 10),
              _RoundButton(
                icon: Icons.videocam_rounded,
                color: AppColors.accentGreen,
                loading: loading,
                onTap: onAccept,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: AppColors.card,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
