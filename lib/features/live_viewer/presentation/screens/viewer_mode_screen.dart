// lib/features/live_viewer/presentation/screens/viewer_mode_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/gift_bottom_sheet.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/chat_panel.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/error_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/gift_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/pause_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/premium_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/reconnection_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/removal_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/role_change_toast.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/status/guest_joined_banner.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/status/top_status_bar.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/controls/comment_input_bar.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/host_video_container.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:uuid/uuid.dart';

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

  // Premium payment UI state (local — not in BLoC)
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

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ViewerBloc>();

    return MultiBlocListener(
      listeners: [
        // ── Stream ended ─────────────────────────────────────────────────────
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
        // We only show a TopSnack here as an additional hint.
        // The actual paywall is rendered by the BlocBuilder below.
        BlocListener<ViewerBloc, ViewerState>(
          listenWhen: (p, n) =>
              !p.requiresPremiumPayment && n.requiresPremiumPayment,
          listener: (ctx, _) {
            // Reset local payment state when paywall appears
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
            p.isStreamUnstable != n.isStreamUnstable ||
            p.showChatUI != n.showChatUI ||
            p.chat != n.chat,
        builder: (context, state) {
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
                    // ── Video (always present so Agora renders) ─────────────
                    HostVideoContainer(repository: widget.repository),

                    // ── Normal viewer UI (hidden when paywall is up) ────────
                    if (!_immersive && !state.requiresPremiumPayment) ...[
                      const TopStatusBar(),
                      const GuestJoinedBanner(),
                      const GiftOverlay(),
                      const PauseOverlay(),
                      const RoleChangeToast(),
                      const ErrorOverlay(),
                      const ReconnectionOverlay(),

                      // Inline unstable banner
                      if (state.isStreamUnstable) const _UnstableBanner(),

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
                          onToggleControls: null,
                        ),
                      ),
                    ],

                    // ── Premium paywall — rendered on TOP of everything ──────
                    // This is OUTSIDE the !_immersive guard so it always shows.
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
          // Tell BLoC access is now granted — health service will confirm
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

// ── Inline unstable banner ────────────────────────────────────────────────────
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
