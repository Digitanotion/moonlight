// lib/features/livestream/presentation/pages/live_host_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/presentation/cubits/chat_cubit.dart';
import 'package:moonlight/features/livestream/presentation/cubits/live_player_cubit.dart';
import 'package:moonlight/features/livestream/presentation/cubits/requests_cubit.dart';
import 'package:moonlight/features/livestream/presentation/widgets/bottom_actions_bar.dart';
import 'package:moonlight/features/livestream/presentation/widgets/cohost_badge.dart';
import 'package:moonlight/features/livestream/presentation/widgets/live_chat_dock.dart';
import 'package:moonlight/features/livestream/presentation/widgets/live_header.dart';
import 'package:moonlight/features/livestream/presentation/widgets/resume_overlay_host.dart';

class LiveHostPage extends StatefulWidget {
  final String livestreamUuid;
  final String channelName;
  final String rtcToken;
  final String appId;
  const LiveHostPage({
    super.key,
    required this.livestreamUuid,
    required this.channelName,
    required this.rtcToken,
    required this.appId,
  });

  @override
  State<LiveHostPage> createState() => _LiveHostPageState();
}

class _LiveHostPageState extends State<LiveHostPage> {
  DateTime _start = DateTime.now();

  @override
  void initState() {
    super.initState();
    // TODO: init Agora as host (publisher) with widget.channelName/widget.rtcToken/widget.appId
    context.read<ChatCubit>().loadHistory();
    context.read<RequestsCubit>().poll();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(_start);
    final player = context.watch<LivePlayerCubit>().state;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F24),
      body: Stack(
        children: [
          // TODO: Agora local preview / remote guest
          Container(color: const Color(0xFF121A3F)),

          LiveHeaderBar(
            title: 'Talking about Mental Health',
            hostName: 'You',
            viewers: 0,
            elapsed: elapsed,
            onClose: _onEnd,
          ),

          if (player.paused) ResumeOverlayHost(onResume: _resume),

          // Guest tag example
          Positioned(
            left: 12,
            bottom: 180,
            child: const CohostBadge(label: 'Guest Luna_Star', muted: true),
          ),

          // Chat dock
          BlocBuilder<ChatCubit, ChatState>(
            builder: (context, s) => LiveChatDock(
              messages: s.messages,
              onSend: (t) => context.read<ChatCubit>().send(t),
            ),
          ),

          BottomActionsBar(
            onChat: () {},
            onViewers: () {},
            onGifts: () {},
            onPauseOrResume: () => player.paused ? _resume() : _pause(),
            paused: player.paused,
            onEndOrLeave: _onEnd,
            isHost: true,
          ),
        ],
      ),
    );
  }

  Future<void> _pause() async {
    await context.read<LivePlayerCubit>().repo.pause(
      context.read<LivePlayerCubit>().state.livestreamUuid!,
    );
    context.read<LivePlayerCubit>().setPaused(true);
  }

  Future<void> _resume() async {
    await context.read<LivePlayerCubit>().repo.resume(
      context.read<LivePlayerCubit>().state.livestreamUuid!,
    );
    context.read<LivePlayerCubit>().setPaused(false);
  }

  Future<void> _onEnd() async {
    await context.read<LivePlayerCubit>().repo.stop(
      context.read<LivePlayerCubit>().state.livestreamUuid!,
    );
    // TODO: leave Agora
    if (mounted) Navigator.pop(context);
  }
}
