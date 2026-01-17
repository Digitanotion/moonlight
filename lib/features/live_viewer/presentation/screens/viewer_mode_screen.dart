// lib/features/live_viewer/presentation/screens/viewer_mode_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/utils/disposal_manager.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/gift_bottom_sheet.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/chat_panel.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/error_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/gift_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/loading_overlay.dart';

import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/pause_overlay.dart';

import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/reconnection_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/removal_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/role_change_toast.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/status/guest_joined_banner.dart';

import 'package:moonlight/features/live_viewer/presentation/widgets/status/host_info_card.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/status/top_status_bar.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/controls/comment_input_bar.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/controls/network_status_indicator.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/host_video_container.dart';

/// Dedicated screen for viewer mode (audience)
class ViewerModeScreen extends StatefulWidget {
  final ViewerRepositoryImpl repository;

  const ViewerModeScreen({super.key, required this.repository});

  @override
  State<ViewerModeScreen> createState() => _ViewerModeScreenState();
}

class _ViewerModeScreenState extends State<ViewerModeScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  bool _immersive = false;
  bool _overlayShown = false;
  bool _showControlPanel = false;

  @override
  void initState() {
    super.initState();

    // ✅ Trigger gift catalog fetch when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<ViewerBloc>();
      // Only fetch if gifts haven't been loaded yet
      if (bloc.state.giftCatalog.isEmpty) {
        bloc.add(GiftsFetchRequested());
      }
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ViewerBloc>();
    final agoraService = sl<AgoraViewerService>();
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v > 300) {
            setState(() => _immersive = true);
          } else if (v < -300) {
            setState(() => _immersive = false);
          }
        },
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              // Background video
              HostVideoContainer(repository: widget.repository),

              // Live ended listener
              BlocListener<ViewerBloc, ViewerState>(
                listenWhen: (p, n) => p.isEnded != n.isEnded,
                listener: (ctx, s) async {
                  if (s.isEnded) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Live has ended.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    await Future.delayed(const Duration(milliseconds: 600));
                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                  }
                },
                child: const SizedBox.shrink(),
              ),

              // When not immersive, show all overlays
              if (!_immersive) ...[
                // Status bars
                const TopStatusBar(),
                const NetworkStatusIndicator(),

                // Host info
                // const HostInfoCard(),

                // Guest banner (when guest joins)
                const GuestJoinedBanner(),

                // Overlays
                const GiftOverlay(),
                const PauseOverlay(),
                // const LoadingOverlay(),
                const RoleChangeToast(),
                BlocListener<ViewerBloc, ViewerState>(
                  listenWhen: (previous, current) =>
                      previous.showRemovalOverlay != current.showRemovalOverlay,
                  listener: (context, state) {
                    if (state.showRemovalOverlay && !_overlayShown) {
                      _overlayShown = true;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          barrierColor: Colors.transparent,
                          builder: (context) => RemovalOverlay(
                            repository: widget.repository,
                            onReturn: () {
                              _performCleanupAndExit(context);
                            },
                          ),
                        );
                      });
                    }
                  },
                  child: const SizedBox.shrink(),
                ),
                const ErrorOverlay(),
                const ReconnectionOverlay(),

                // Chat panel
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 80,
                    ),
                    child: BlocBuilder<ViewerBloc, ViewerState>(
                      buildWhen: (p, n) =>
                          p.showChatUI != n.showChatUI || p.chat != n.chat,
                      builder: (_, s) => Visibility(
                        visible: s.showChatUI,
                        child: const ChatPanel(),
                      ),
                    ),
                  ),
                ),

                // Comment input bar
                Align(
                  alignment: Alignment.bottomCenter,
                  child: CommentInputBar(
                    controller: _commentCtrl,
                    onSend: (text) {
                      final t = text.trim();
                      if (t.isNotEmpty) {
                        bloc.add(CommentSent(t));
                        _commentCtrl.clear();
                      }
                    },
                    onGiftTap: () {
                      showGiftBottomSheet(context, widget.repository);
                    },
                    onToggleControls: () {
                      setState(() {
                        _showControlPanel = !_showControlPanel;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _performCleanupAndExit(BuildContext context) async {
    debugPrint('🧹 Performing cleanup before exit...');

    // 1. Get the livestream ID
    final livestreamId = widget.repository.livestreamIdNumeric;

    // 2. Dispose repository
    widget.repository.dispose();

    // 3. Leave Agora channel
    try {
      await sl<AgoraViewerService>().leave();
      debugPrint('✅ Left Agora channel');
    } catch (e) {
      debugPrint('⚠️ Error leaving Agora: $e');
    }

    // 4. Unsubscribe from Pusher channels
    final pusherService = sl<PusherService>();
    final channels = [
      'live.$livestreamId.meta',
      'live.$livestreamId.chat',
      'live.$livestreamId.join',
      'live.$livestreamId',
      'live.$livestreamId.gifts',
    ];

    for (final channel in channels) {
      try {
        await pusherService.unsubscribe(channel);
        pusherService.clearChannelHandlers(channel);
      } catch (e) {
        debugPrint('⚠️ Error unsubscribing from $channel: $e');
      }
    }

    debugPrint('✅ Cleanup completed');

    // 5. Navigate back
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // Close dialog
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // Close screen
    } else {
      // Fallback: Navigate to home
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}
