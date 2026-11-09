// lib/features/video_call/presentation/widgets/ongoing_call_bar.dart
//
// Green "Ongoing call · 2:31 — tap to return" bar shown above the whole app
// while an audio call is minimised. Wraps MaterialApp's builder like
// IncomingCallBanner and reads the app-wide VideoCallBloc from GetIt.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';
import 'package:moonlight/features/video_call/presentation/pages/active_call_screen.dart';
import 'package:moonlight/features/video_call/presentation/widgets/audio_call_view.dart';

class OngoingCallBar extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  const OngoingCallBar({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<OngoingCallBar> createState() => _OngoingCallBarState();
}

class _OngoingCallBarState extends State<OngoingCallBar> {
  StreamSubscription<VideoCallState>? _sub;
  VideoCallState? _state;

  VideoCallBloc? get _bloc =>
      sl.isRegistered<VideoCallBloc>() ? sl<VideoCallBloc>() : null;

  @override
  void initState() {
    super.initState();
    ActiveCallScreen.isOpen.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  void _listen() {
    final bloc = _bloc;
    if (bloc == null) {
      // GetIt may still be warming up right after launch.
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _listen();
      });
      return;
    }
    _state = bloc.state;
    _sub = bloc.stream.listen((s) {
      // A minimised audio call that ended: nothing to show — reset so the
      // next call isn't blocked by a lingering "ended" state.
      if (s.phase == VideoCallPhase.ended &&
          (s.session?.isAudio ?? false) &&
          !ActiveCallScreen.isOpen.value) {
        bloc.add(CallDismissed());
      }
      if (mounted) setState(() => _state = s);
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    ActiveCallScreen.isOpen.removeListener(_refresh);
    super.dispose();
  }

  void _return() {
    final bloc = _bloc;
    final nav = widget.navigatorKey.currentState;
    if (bloc == null || nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) =>
            BlocProvider.value(value: bloc, child: const ActiveCallScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final show =
        s != null &&
        s.phase == VideoCallPhase.active &&
        (s.session?.isAudio ?? false) &&
        !ActiveCallScreen.isOpen.value;
    final other = s == null
        ? null
        : (s.isCaller ? s.session?.callee : s.session?.caller);
    return Stack(
      children: [
        widget.child,
        if (show)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: const Color(0xFF1FA463),
              child: InkWell(
                onTap: _return,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.call_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ongoing call with ${other?.displayName ?? 'someone'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        CallElapsed(
                          since: s.session?.connectedAt,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Return',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
