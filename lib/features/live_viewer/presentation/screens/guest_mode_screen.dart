// lib/features/live_viewer/presentation/screens/guest_mode_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/gift_bottom_sheet.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/glass.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/chat_panel.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/error_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/gift_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/loading_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/pause_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/premium_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/reconnection_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/removal_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/role_change_toast.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/status/top_status_bar.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/controls/comment_input_bar.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/controls/guest_control_panel.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/dynamic_split_screen.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:uuid/uuid.dart';

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
  String? _lastNotifiedRole;

  // Premium payment UI state (local)
  bool _isProcessingPayment = false;
  String? _paymentError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<ViewerBloc>();
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

  void _openControlSheet(BuildContext context) {
    showGuestControlSheet(
      context,
      agoraService: sl<AgoraViewerService>(),
      onEndCall: () => _performCleanupAndExit(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ViewerBloc>();

    return MultiBlocListener(
      listeners: [
        // ── Role promotion ────────────────────────────────────────────────────
        BlocListener<ViewerBloc, ViewerState>(
          listenWhen: (p, n) => p.currentRole != n.currentRole,
          listener: (ctx, state) {
            final role = state.currentRole;
            if (role == null || role == _lastNotifiedRole) return;
            _lastNotifiedRole = role;
            if (role == 'guest' || role == 'cohost') {
              TopSnack.show(
                ctx,
                "You're now a co-host! Tap ••• to control mic & camera.",
                icon: Icons.star_rounded,
                accent: const Color(0xFFFF7A00),
              );
            } else if (role == 'audience') {
              TopSnack.info(ctx, 'You have been moved back to audience.');
            }
          },
        ),

        // ── Stream ended ──────────────────────────────────────────────────────
        BlocListener<ViewerBloc, ViewerState>(
          listenWhen: (p, n) => !p.isEnded && n.isEnded,
          listener: (ctx, state) async {
            TopSnack.info(
              ctx,
              state.errorMessage ?? 'This live stream has ended.',
            );
            await Future.delayed(const Duration(milliseconds: 1200));
            if (ctx.mounted && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          },
        ),

        // ── Stream unstable / recovered ───────────────────────────────────────
        BlocListener<ViewerBloc, ViewerState>(
          listenWhen: (p, n) => p.isStreamUnstable != n.isStreamUnstable,
          listener: (ctx, state) {
            if (state.isStreamUnstable) {
              TopSnack.warning(
                ctx,
                state.streamUnstableMessage ??
                    'Stream is unstable — trying to reach host network…',
                duration: const Duration(seconds: 6),
              );
            } else {
              TopSnack.success(ctx, 'Stream is back online!');
            }
          },
        ),

        // ── Premium access required ───────────────────────────────────────────
        BlocListener<ViewerBloc, ViewerState>(
          listenWhen: (p, n) =>
              !p.requiresPremiumPayment && n.requiresPremiumPayment,
          listener: (ctx, _) {
            setState(() {
              _isProcessingPayment = false;
              _paymentError = null;
            });
            TopSnack.warning(ctx, 'This stream requires payment to watch.');
          },
        ),

        // ── Removal overlay ───────────────────────────────────────────────────
        BlocListener<ViewerBloc, ViewerState>(
          listenWhen: (p, n) => p.showRemovalOverlay != n.showRemovalOverlay,
          listener: (ctx, state) {
            if (state.showRemovalOverlay && !_overlayShown) {
              _overlayShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDialog(
                  context: ctx,
                  barrierDismissible: false,
                  barrierColor: Colors.transparent,
                  builder: (_) => RemovalOverlay(
                    repository: widget.repository,
                    onReturn: () => _performCleanupAndExit(ctx),
                  ),
                );
              });
            }
          },
        ),
      ],

      // ── BlocBuilder rebuilds on ALL relevant fields ───────────────────────
      child: BlocBuilder<ViewerBloc, ViewerState>(
        buildWhen: (p, n) =>
            p.requiresPremiumPayment != n.requiresPremiumPayment ||
            p.currentRole != n.currentRole ||
            p.isStreamUnstable != n.isStreamUnstable ||
            p.showChatUI != n.showChatUI ||
            p.chat != n.chat,
        builder: (context, state) {
          final isCurrentUserGuest =
              state.currentRole == 'guest' || state.currentRole == 'cohost';

          return Scaffold(
            backgroundColor: Colors.black,
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v > 300) setState(() => _immersive = true);
                if (v < -300) setState(() => _immersive = false);
              },
              child: SafeArea(
                top: true,
                bottom: false,
                child: Stack(
                  children: [
                    // ── Split screen video layout ────────────────────────────
                    DynamicSplitScreen(
                      repository: widget.repository,
                      isCurrentUserGuest: isCurrentUserGuest,
                    ),

                    // ── Normal guest UI (hidden when paywall is up) ──────────
                    if (!_immersive && !state.requiresPremiumPayment) ...[
                      const TopStatusBar(),

                      if (state.isStreamUnstable) const _UnstableBanner(),

                      const _GiftToast(),
                      const GiftOverlay(),
                      const PauseOverlay(),
                      const LoadingOverlay(),
                      const RoleChangeToast(),
                      const ErrorOverlay(),
                      const ReconnectionOverlay(),

                      // Chat
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
                                p.showChatUI != n.showChatUI ||
                                p.chat != n.chat,
                            builder: (_, s) => Visibility(
                              visible: s.showChatUI,
                              child: const ChatPanel(),
                            ),
                          ),
                        ),
                      ),

                      // Input bar
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
                          onGiftTap: () =>
                              showGiftBottomSheet(context, widget.repository),
                          onToggleControls: isCurrentUserGuest
                              ? () => _openControlSheet(context)
                              : null,
                        ),
                      ),
                    ],

                    // ── Premium paywall — TOP of stack, always visible ───────
                    if (state.requiresPremiumPayment)
                      Positioned.fill(
                        child: PremiumOverlay(
                          fee: state.premiumEntryFeeCoins,
                          isLoading: _isProcessingPayment,
                          statusMessage: _paymentError,
                          onOpenPayment: () => _handlePremiumPayment(context),
                          onOpenWallet: () =>
                              Navigator.of(context).pushNamed('/wallet'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Payment handler ─────────────────────────────────────────────────────────
  Future<void> _handlePremiumPayment(BuildContext context) async {
    setState(() {
      _isProcessingPayment = true;
      _paymentError = null;
    });

    try {
      final repo = sl<LiveFeedRepository>();
      final response = await repo.payPremium(
        liveId: widget.repository.livestreamIdNumeric,
        idempotencyKey: const Uuid().v4(),
      );

      final status = (response['status'] ?? '').toString().toLowerCase();
      final message = (response['message'] as String?) ?? '';

      if (status == 'success') {
        if (mounted) {
          setState(() => _isProcessingPayment = false);
          context.read<ViewerBloc>().add(const PremiumAccessGranted());
          TopSnack.success(context, 'Access unlocked! Enjoy the stream.');
        }
      } else {
        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
            _paymentError = message.isNotEmpty
                ? message
                : 'Payment failed. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _paymentError = 'Network error. Please try again.';
        });
      }
    }
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────────
  void _performCleanupAndExit(BuildContext context) async {
    final livestreamId = widget.repository.livestreamIdNumeric;
    widget.repository.dispose();
    try {
      await sl<AgoraViewerService>().leave();
    } catch (_) {}
    final pusher = sl<PusherService>();
    for (final ch in [
      'live.$livestreamId.meta',
      'live.$livestreamId.chat',
      'live.$livestreamId.join',
      'live.$livestreamId',
      'live.$livestreamId.gifts',
    ]) {
      try {
        await pusher.unsubscribe(ch);
        pusher.clearChannelHandlers(ch);
      } catch (_) {}
    }
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}

// ── Unstable banner ───────────────────────────────────────────────────────────
class _UnstableBanner extends StatelessWidget {
  const _UnstableBanner();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 56,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4A3A0F).withOpacity(0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFA726).withOpacity(0.4)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.wifi_tethering_error_rounded,
              color: Color(0xFFFFA726),
              size: 16,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Stream unstable — trying to reach host network…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gift toast ────────────────────────────────────────────────────────────────
class _GiftToast extends StatelessWidget {
  const _GiftToast();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.showGiftToast != n.showGiftToast || p.gift != n.gift,
      builder: (_, s) {
        if (!s.showGiftToast || s.gift == null) return const SizedBox.shrink();
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
                              "${g.from} sent a '${g.giftName}' gift",
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
