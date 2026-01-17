// lib/features/live_viewer/presentation/screens/guest_mode_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/gifts/presentation/gift_bottom_sheet.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/gift_bottom_sheet.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/glass.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/chat_panel.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/status/top_status_bar.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/controls/comment_input_bar.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/controls/guest_control_panel.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/controls/network_status_indicator.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/dynamic_split_screen.dart'; // NEW
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/error_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/gift_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/loading_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/pause_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/reconnection_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/removal_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/role_change_toast.dart';

/// Enhanced GuestModeScreen that handles both:
/// 1. Current user is guest: Shows Host + Local Preview
/// 2. Current user is viewer: Shows Host + Remote Guest Video
class GuestModeScreen extends StatefulWidget {
  final ViewerRepositoryImpl repository;

  const GuestModeScreen({super.key, required this.repository});

  @override
  State<GuestModeScreen> createState() => _GuestModeScreenState();
}

class _GuestModeScreenState extends State<GuestModeScreen> {
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

    return BlocBuilder<ViewerBloc, ViewerState>(
      builder: (context, state) {
        final isCurrentUserGuest =
            state.currentRole == 'guest' || state.currentRole == 'cohost';
        final hasActiveGuest = state.activeGuestUuid != null;

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
                  // NEW: Dynamic Split Screen Layout
                  DynamicSplitScreen(
                    repository: widget.repository,
                    isCurrentUserGuest: isCurrentUserGuest,
                  ),

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
                    // const NetworkStatusIndicator(),

                    // Show guest controls only if current user is guest
                    if (isCurrentUserGuest && _showControlPanel)
                      Positioned(
                        top: 120, // Position from TOP of screen
                        left: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            // Tap on panel background to close
                            setState(() => _showControlPanel = false);
                          },
                          child: Column(
                            children: [
                              // Guest Control Panel
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: GuestControlPanel(
                                  agoraService: agoraService,
                                  onEndCall: () {
                                    _performCleanupAndExit(context);
                                  },
                                ),
                              ),

                              // Optional close hint
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Tap to close controls',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Overlays
                    _GiftToast(),
                    const GiftOverlay(),

                    const PauseOverlay(),
                    const LoadingOverlay(),
                    const RoleChangeToast(),
                    BlocListener<ViewerBloc, ViewerState>(
                      listenWhen: (previous, current) =>
                          previous.showRemovalOverlay !=
                          current.showRemovalOverlay,
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
                                onReturn: () => _performCleanupAndExit(context),
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
                    // In GuestModeScreen.dart - Update CommentInputBar
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
      },
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

class _GiftToast extends StatelessWidget {
  const _GiftToast();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.showGiftToast != n.showGiftToast || p.gift != n.gift,
      builder: (_, s) {
        if (!s.showGiftToast || s.gift == null) {
          return const SizedBox.shrink();
        }
        final g = s.gift!;
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 210),
            child: glass(
              radius: 16,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.card_giftcard,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${g.from} just sent streamer a ‘${g.giftName}’ gift',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '(worth ${g.coins} coins!)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.redeem,
                        color: Colors.orangeAccent,
                        size: 20,
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
}
