// lib/features/livestream/presentation/pages/live_viewer_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/livestream/presentation/widgets/bottom_actions_bar.dart';
import 'package:moonlight/features/livestream/presentation/widgets/gift_tray.dart';
import 'package:moonlight/features/livestream/presentation/widgets/live_chat_dock.dart';
import 'package:moonlight/features/livestream/presentation/widgets/live_header.dart';
import 'package:moonlight/features/livestream/presentation/widgets/pause_overlay.dart';
import 'package:moonlight/features/livestream/presentation/widgets/pending_chip.dart';
import 'package:moonlight/features/livestream/presentation/widgets/request_join_bar.dart';
import '../cubits/live_player_cubit.dart';
import '../cubits/chat_cubit.dart';
import '../cubits/gifts_cubit.dart';
import '../cubits/viewers_cubit.dart';

class LiveViewerPage extends StatefulWidget {
  final String livestreamUuid;
  const LiveViewerPage({super.key, required this.livestreamUuid});

  @override
  State<LiveViewerPage> createState() => _LiveViewerPageState();
}

class _LiveViewerPageState extends State<LiveViewerPage> {
  AgoraService get _agora => sl<AgoraService>(); // via your locator
  DateTime _joined = DateTime.now();
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    context.read<LivePlayerCubit>().loadToken(widget.livestreamUuid);
    context.read<ChatCubit>().loadHistory();
    context.read<ViewersCubit>().refresh();
  }

  @override
  void dispose() {
    _agora.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(_joined);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F24),
      body: BlocListener<LivePlayerCubit, LivePlayerState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, s) async {
          if (s.status == LiveStatus.ready &&
              s.rtcToken != null &&
              s.appId != null &&
              s.channelName != null) {
            // init + join as audience
            if (!_agora.isReady) await _agora.init(s.appId!);
            final me =
                await sl<AuthLocalDataSource>().getCurrentUserUuid() ??
                'anon-${DateTime.now().microsecondsSinceEpoch}';
            await _agora.joinAs(
              token: s.rtcToken!,
              channelName: s.channelName!,
              userUuid: me,
              asHost: false,
            );
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // VIDEO: use Agora views
            _ViewerVideo(),
            // TODO: Agora video view for host; when guest accepted, show split layout
            Container(color: const Color(0xFF10162F)),

            // Header
            BlocBuilder<ViewersCubit, ViewersState>(
              builder: (context, vState) => LiveHeaderBar(
                title: 'Talking about Mental Health',
                hostName: 'Emma watson',
                viewers: vState.count,
                elapsed: elapsed,
                onClose: () => Navigator.pop(context),
              ),
            ),

            // Paused overlay (viewer)
            BlocBuilder<LivePlayerCubit, LivePlayerState>(
              builder: (context, s) => s.paused
                  ? PauseOverlayViewer(
                      hostDisplay: 'Emma',
                      hostHandle: 'Emma_wilson',
                      onLeave: () => Navigator.pop(context),
                    )
                  : const SizedBox.shrink(),
            ),

            // Chat Dock
            BlocBuilder<ChatCubit, ChatState>(
              builder: (context, s) => LiveChatDock(
                messages: s.messages.take(20).toList(),
                onSend: (t) => context.read<ChatCubit>().send(t),
              ),
            ),

            // Gifts Tray
            BlocBuilder<GiftsCubit, GiftsState>(
              builder: (context, s) => GiftTray(
                balance: s.balance,
                onGiftTap: (type, coins) =>
                    context.read<GiftsCubit>().sendGift(type, coins),
              ),
            ),

            // Request to Join / Pending chip
            if (_pending)
              const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: PendingChip(
                    text: 'Request sent. You’ll be notified if accepted.',
                  ),
                ),
              ),
            RequestJoinBar(
              pending: _pending,
              onRequest: () async {
                // API call
                await context.read<LivePlayerCubit>().repo.requestCohost(
                  widget.livestreamUuid,
                );
                setState(() => _pending = true);
              },
            ),

            // Bottom bar
            BlocBuilder<LivePlayerCubit, LivePlayerState>(
              builder: (context, s) => BottomActionsBar(
                onChat: () {},
                onViewers: () => context.read<ViewersCubit>().refresh(),
                onGifts: () {},
                onPauseOrResume: () {},
                paused: s.paused,
                onEndOrLeave: () => Navigator.pop(context),
                isHost: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerVideo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final agora = sl<AgoraService>();
    return StreamBuilder<int>(
      stream: agora.onRemoteUser, // remote UID
      builder: (_, snapshot) {
        if (!agora.isReady) {
          return const ColoredBox(color: Color(0xFF10162F));
        }
        final uid = snapshot.data;
        if (uid == null) {
          // Waiting for host video
          return const ColoredBox(color: Color(0xFF10162F));
        }
        return agora.remoteView(uid);
      },
    );
  }
}
