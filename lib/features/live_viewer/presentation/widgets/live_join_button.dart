// lib/features/live_viewer/presentation/widgets/live_join_button.dart
//
// The viewer's big red "Join" button on the side of a livestream. Tapping
// asks the host to bring you into the box (on camera with them); the host
// gets a pop-up and approves or declines. Approval arrives as a role change
// and the screen switches to guest mode on its own.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/widgets/top_snack.dart';

enum _JoinState { idle, sending, waiting }

class LiveJoinButton extends StatefulWidget {
  final ViewerRepositoryImpl repository;
  const LiveJoinButton({super.key, required this.repository});

  @override
  State<LiveJoinButton> createState() => _LiveJoinButtonState();
}

class _LiveJoinButtonState extends State<LiveJoinButton>
    with SingleTickerProviderStateMixin {
  _JoinState _state = _JoinState.idle;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  String get _base => '/api/v1/live/${widget.repository.livestreamParam}';
  String get _channel => 'live.${widget.repository.livestreamIdNumeric}.join';

  @override
  void initState() {
    super.initState();
    sl<PusherService>().bind(_channel, 'join.decided', _onDecided);
  }

  @override
  void dispose() {
    sl<PusherService>().unbind(_channel, 'join.decided', _onDecided);
    _pulse.dispose();
    super.dispose();
  }

  void _onDecided(Map<String, dynamic> m) {
    final me = sl<CurrentUserService>().getCurrentUserId();
    if (me == null || m['user_uuid']?.toString() != me || !mounted) return;
    final status = m['status']?.toString();
    setState(() => _state = _JoinState.idle);
    if (status == 'accepted') {
      HapticFeedback.mediumImpact();
      TopSnack.success(context, 'You\'re in! Turning on your camera…');
    } else if (status == 'declined') {
      TopSnack.error(context, 'The host didn\'t accept this time.');
    }
  }

  Future<void> _ask() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF14101F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF2D55), Color(0xFFFF7A00)],
                  ),
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Join the host on camera?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The host will get your request. Once they accept, everyone '
                'watching will see and hear you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text(
                    'Ask to join',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text(
                  'Not now',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _state = _JoinState.sending);
    try {
      await sl<DioClient>().dio.post('$_base/request-join');
      if (!mounted) return;
      setState(() => _state = _JoinState.waiting);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _JoinState.idle);
      String msg = 'Couldn\'t send your request. Try again.';
      if (e is DioException) {
        final d = e.response?.data;
        if (d is Map && d['message'] is String) msg = d['message'];
      }
      TopSnack.error(context, msg);
    }
  }

  Future<void> _cancel() async {
    setState(() => _state = _JoinState.idle);
    try {
      await sl<DioClient>().dio.post('$_base/request-join/cancel');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _state == _JoinState.waiting;
    final sending = _state == _JoinState.sending;
    return GestureDetector(
      onTap: sending ? null : (waiting ? _cancel : _ask),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft red ripple so it's impossible to miss.
              if (!waiting)
                Container(
                  width: 62 + 22 * t,
                  height: 62 + 22 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xFFFF2D55,
                    ).withValues(alpha: 0.35 * (1 - t)),
                  ),
                ),
              child!,
            ],
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: waiting
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFF2D55), Color(0xFFE0115F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: waiting ? Colors.black54 : null,
                border: Border.all(
                  color: waiting ? const Color(0xFFFF2D55) : Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2D55).withValues(alpha: 0.6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Center(
                child: sending || waiting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: waiting ? Colors.black54 : const Color(0xFFFF2D55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                waiting ? 'Waiting… ✕' : 'JOIN',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
