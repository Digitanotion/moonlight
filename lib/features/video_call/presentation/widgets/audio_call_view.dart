// lib/features/video_call/presentation/widgets/audio_call_view.dart
//
// In-call screen for a free audio call (started from a chat): the other
// person's photo blurred behind, their photo in a circle, name, running
// time, and Speaker / Mute / End — plus a minimise button that leaves the
// call running in the background (see OngoingCallBar).

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/services/video_call_agora_service.dart';

class AudioCallView extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final DateTime? connectedAt;
  final bool reconnecting;
  final VideoCallAgoraService agora;
  final VoidCallback onEnd;
  final VoidCallback onMinimize;

  const AudioCallView({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.connectedAt,
    required this.reconnecting,
    required this.agora,
    required this.onEnd,
    required this.onMinimize,
  });

  bool get _hasAvatar => (avatarUrl ?? '').startsWith('http');

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: const Color(0xFF5A3E2E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_hasAvatar)
            CachedNetworkImage(
              imageUrl: avatarUrl!,
              fit: BoxFit.cover,
              memCacheWidth: 200,
            ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF7A5038).withValues(alpha: 0.55),
                      const Color(0xFF4A3426).withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: pad.top + 12,
            left: 16,
            child: _RoundButton(
              size: 46,
              color: Colors.white.withValues(alpha: 0.22),
              onTap: onMinimize,
              child: const Icon(
                Icons.close_fullscreen_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          Column(
            children: [
              const Spacer(flex: 5),
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2A2153),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: _hasAvatar
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        fit: BoxFit.cover,
                        width: 150,
                        height: 150,
                        memCacheWidth: 300,
                      )
                    : Text(
                        name.trim().isEmpty
                            ? '?'
                            : name.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(height: 26),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.call_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  reconnecting
                      ? const Text(
                          'Reconnecting…',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        )
                      : CallElapsed(
                          since: connectedAt,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                ],
              ),
              const Spacer(flex: 7),
              ListenableBuilder(
                listenable: agora,
                builder: (context, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallAction(
                      label: 'Speaker',
                      active: agora.speakerOn,
                      icon: Icons.volume_up_rounded,
                      onTap: () => agora.setSpeakerOn(!agora.speakerOn),
                    ),
                    _CallAction(
                      label: agora.isMicEnabled ? 'Mute' : 'Unmute',
                      active: !agora.isMicEnabled,
                      icon: agora.isMicEnabled
                          ? Icons.mic_rounded
                          : Icons.mic_off_rounded,
                      onTap: () => agora.setMicEnabled(!agora.isMicEnabled),
                    ),
                    _CallAction(
                      label: 'End',
                      danger: true,
                      icon: Icons.call_end_rounded,
                      onTap: onEnd,
                    ),
                  ],
                ),
              ),
              SizedBox(height: pad.bottom + 48),
            ],
          ),
        ],
      ),
    );
  }
}

/// "0:11", "12:04", "1:02:33" — counting up from [since].
class CallElapsed extends StatefulWidget {
  final DateTime? since;
  final TextStyle style;
  const CallElapsed({super.key, required this.since, required this.style});

  @override
  State<CallElapsed> createState() => _CallElapsedState();
}

class _CallElapsedState extends State<CallElapsed> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    final s = since == null
        ? 0
        : DateTime.now()
              .difference(since.toLocal())
              .inSeconds
              .clamp(0, 1 << 30);
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final text = h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
        : '$m:${sec.toString().padLeft(2, '0')}';
    return Text(text, style: widget.style);
  }
}

class _CallAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool danger;
  final VoidCallback onTap;
  const _CallAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFB3201B)
        : active
        ? Colors.white
        : Colors.white.withValues(alpha: 0.92);
    final fg = danger ? Colors.white : Colors.black;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          size: 76,
          color: bg,
          border: active && !danger
              ? Border.all(color: const Color(0xFF39D98A), width: 3)
              : null,
          onTap: onTap,
          child: Icon(icon, color: fg, size: 32),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final double size;
  final Color color;
  final Widget child;
  final VoidCallback onTap;
  final BoxBorder? border;
  const _RoundButton({
    required this.size,
    required this.color,
    required this.child,
    required this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: border,
      ),
      alignment: Alignment.center,
      child: child,
    ),
  );
}
