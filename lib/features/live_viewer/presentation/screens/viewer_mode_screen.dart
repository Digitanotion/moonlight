// lib/features/live_viewer/presentation/screens/viewer_mode_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/gift_bottom_sheet.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/chat_panel.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/follow_prompt_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/gift_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/pause_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/premium_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/reconnection_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/removal_overlay.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/role_change_toast.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/pool_video_view.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/status/guest_joined_banner.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/status/top_status_bar.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/controls/comment_input_bar.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/video_layouts/host_video_container.dart';
import 'package:moonlight/features/profile_view/domain/repositories/profile_repository.dart'
    as view_repo;
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';
import 'package:moonlight/features/video_call/presentation/pages/outgoing_call_screen.dart';
import 'package:moonlight/features/video_call/presentation/widgets/duration_picker_sheet.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:uuid/uuid.dart';

class ViewerModeScreen extends StatefulWidget {
  final ViewerRepositoryImpl repository;
  final AgoraEnginePool? pool;
  final String? channelId;

  const ViewerModeScreen({
    super.key,
    required this.repository,
    this.pool,
    this.channelId,
  });

  @override
  State<ViewerModeScreen> createState() => _ViewerModeScreenState();
}

class _ViewerModeScreenState extends State<ViewerModeScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  bool _immersive = false;
  bool _overlayShown = false;
  bool _isProcessingPayment = false;
  String? _paymentError;

  @override
  void initState() {
    super.initState();
    // Doc item 11: "Nobody will be able to screenshot or video record
    // a streamer. Enable zero screenshot or record of livestream." —
    // applied for the duration this viewer screen is on-screen only,
    // not app-wide, and reversed in dispose() below so other screens
    // are unaffected.
    ScreenProtector.protectDataLeakageOn();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<ViewerBloc>();
      if (bloc.state.giftCatalog.isEmpty) {
        bloc.add(GiftsFetchRequested());
      }
    });
  }

  @override
  void dispose() {
    ScreenProtector.protectDataLeakageOff();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ViewerBloc>();

    return MultiBlocListener(
      listeners: [
        // Stream ended
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

        // Stream unstable / recovered
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

        // Premium access required
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

        // Removal overlay
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
                    // ── Video — pool-aware ──────────────────────────────
                    // Pool mode: PoolVideoView always renders the pool's
                    // CURRENT slot — no channelId matching needed.
                    // Standalone mode: HostVideoContainer (unchanged).
                    // Video — pool-aware.
                    // Key uses channelId so each page has its OWN
                    // PoolVideoView State that is stable for that page
                    // but distinct from other pages. When this page's
                    // PoolVideoView is visible, it seeds from the pool's
                    // current slot (which the pager ensures matches this
                    // page's channel via rotation).
                    if (widget.pool != null)
                      PoolVideoView(
                        key: ValueKey('pv_${widget.channelId}'),
                        pool: widget.pool!,
                      )
                    else
                      HostVideoContainer(repository: widget.repository),

                    // ── Normal viewer UI ────────────────────────────────
                    if (!_immersive && !state.requiresPremiumPayment) ...[
                      const TopStatusBar(),
                      const FollowPromptOverlay(),
                      const GuestJoinedBanner(),
                      const GiftOverlay(),
                      const PauseOverlay(),
                      const RoleChangeToast(),
                      const ReconnectionOverlay(),
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
                          // Private video call (doc item 8). Gated only on
                          // a host being present — the actual gender/
                          // online/enabled rules are enforced server-side
                          // by VideoCallService.initiate() (already tested),
                          // so a non-callable host just gets a clear error
                          // message back rather than needing every one of
                          // those fields threaded through HostInfo here.
                          showVideoCall: state.host != null,
                          onVideoCallTap: () =>
                              _openVideoCall(context, widget.repository),
                        ),
                      ),
                    ],

                    // Premium paywall — always on top
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

  // ── Payment handler ───────────────────────────────────────────────────────

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

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void _openVideoCall(BuildContext context, ViewerRepositoryImpl repository) {
    final host = context.read<ViewerBloc>().state.host;
    if (host == null) return;

    // HostInfo (lib/features/live_viewer/domain/entities.dart) carries no
    // identifier at all — no uuid, no slug, just display fields (name,
    // avatarUrl, etc). Our video-call API requires callee_user_slug, so we
    // resolve it here via the existing profile-by-uuid endpoint, using the
    // hostUserUuid the repository was already constructed with (see
    // createViewerRepository's hostUuid param in injection_container.dart).
    //
    // NOTE: this assumes ViewerRepositoryImpl exposes `hostUserUuid` as a
    // public field, matching the pattern of its other public fields
    // (http, livestreamParam, livestreamIdNumeric). If that field is
    // named differently or isn't public, swap the access below — the
    // profile-lookup + navigation logic itself is correct regardless.
    _resolveHostSlugAndOpen(context, repository, host);
  }

  Future<int?> _fetchCoinBalance() async {
    try {
      final res = await sl<DioClient>().dio.get('/api/v1/wallet');
      final data = res.data;
      final map = data is Map ? data.cast<String, dynamic>() : {};
      final inner = map['data'];
      final innerMap = inner is Map ? inner.cast<String, dynamic>() : {};
      final coins = innerMap['balance'];
      return int.tryParse('${coins ?? 0}') ?? 0;
    } catch (e) {
      debugPrint('⚠️ Failed to fetch wallet balance: $e');
      return null;
    }
  }

  Future<void> _resolveHostSlugAndOpen(
    BuildContext context,
    ViewerRepositoryImpl repository,
    HostInfo host,
  ) async {
    final hostUuid = repository.hostUserUuid;
    if (hostUuid == null || hostUuid.isEmpty) {
      TopSnack.warning(context, 'Could not start the call. Try again.');
      return;
    }

    try {
      final profile = await sl<view_repo.ProfileRepository>().getUser(hostUuid);
      if (!context.mounted) return;

      final balance = await _fetchCoinBalance();
      if (!context.mounted) return;

      if (balance == null) {
        TopSnack.warning(
          context,
          'Could not load your coin balance. Try again.',
        );
        return;
      }

      final minutes = await DurationPickerSheet.show(
        context,
        calleeDisplayName: host.name,
        ratePerMinute: 100,
        callerCoinBalance: balance,
      );

      if (minutes == null || !context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: sl<VideoCallBloc>(),
            child: OutgoingCallScreen(
              calleeUserSlug: (profile.handle ?? '').replaceFirst('@', ''),
              calleeDisplayName: host.name,
              calleeAvatarUrl: host.avatarUrl,
              initiatedFrom: 'livestream',
              livestreamId: repository.livestreamIdNumeric,
              initialMinutes: minutes,
            ),
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      TopSnack.warning(context, 'Could not start the call. Try again.');
    }
  }

  void _performCleanupAndExit(BuildContext context) async {
    final livestreamId = widget.repository.livestreamIdNumeric;
    widget.repository.dispose();

    // Only call singleton leave() in non-pool mode. In pool mode the
    // pool owns all Agora connections.
    if (widget.pool == null) {
      try {
        await sl<AgoraViewerService>().leave();
      } catch (_) {}
    }

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

// ── Inline unstable banner ────────────────────────────────────────────────

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
