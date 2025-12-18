// lib/features/live_viewer/presentation/screens/live_viewer_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/gifts/presentation/gift_bottom_sheet.dart';
import 'package:moonlight/features/gifts/presentation/gift_overlay_layer.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/video_surface_provider.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/viewers_list_screen.dart';
import '../../domain/entities.dart';
import '../../domain/repositories/viewer_repository.dart';
import '../bloc/viewer_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
import 'package:moonlight/features/wallet/services/idempotency_helper.dart';
import 'package:moonlight/widgets/top_snack.dart';

// NEW imports for pager / repo builder
import 'package:moonlight/features/home/domain/entities/live_item.dart';
import 'package:moonlight/core/services/pusher_service.dart';

/// ===================================================================
/// LIVE VIEWER SCREEN (unchanged behavior) - kept intact for drop-in
/// ===================================================================
class LiveViewerScreen extends StatefulWidget {
  final ViewerRepository repository; // injected
  const LiveViewerScreen({super.key, required this.repository});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  final _commentCtrl = TextEditingController();
  bool _immersive = false;
  bool _hasPaid = false;
  bool _premiumSheetLoading = false;
  String? _premiumStatusMessage;

  // Ensure we only auto-start the bloc once from the screen (defensive)
  bool _didAutoStartBloc = false;

  @override
  void initState() {
    super.initState();
    // Post-frame: if there is a ViewerBloc above us and it hasn't been started,
    // add ViewerStarted as a defensive fallback. The pager already adds it
    // when created, but some call-sites might not — this prevents silent no-op.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final bloc = context.read<ViewerBloc>();
        if (bloc != null && !_didAutoStartBloc) {
          // Add the start event only once
          bloc.add(const ViewerStarted());
          _didAutoStartBloc = true;
        }
      } catch (_) {
        // ignore: defensive; if no bloc is found just continue
      }
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _routeArgs(BuildContext context) {
    final settingsArgs = ModalRoute.of(context)?.settings.arguments;
    if (settingsArgs is Map<String, dynamic>) return settingsArgs;
    if (settingsArgs is Map) return Map<String, dynamic>.from(settingsArgs);
    return null;
  }

  // ... rest of your existing _LiveViewerScreenState code unchanged ...

  @override
  Widget build(BuildContext context) {
    // Read route args so we can detect if this stream is premium
    final a = _routeArgs(context);
    final bool isPremium =
        (a != null &&
        (a['isPremium'] != null ? (a['isPremium'] as int) == 1 : false));
    final int? premiumFee = a != null ? (a['premiumFee'] as int?) : null;
    final int? numericLiveId = a != null ? (a['id'] as int?) : null;

    return Scaffold(
      body: _BackgroundVideo(
        repository: widget.repository,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Horizontal swipe: primaryVelocity > 0 = swipe right, < 0 = swipe left
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            // tweak threshold (300) if needed to change sensitivity
            if (v > 300) {
              setState(() => _immersive = true); // swipe right -> hide overlays
            } else if (v < -300) {
              setState(() => _immersive = false); // swipe left -> show overlays
            }
          },
          child: SafeArea(
            top: true,
            bottom: false,
            child: Stack(
              children: [
                // Background & video are below; overlays above
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

                // Two-up layout overlay - MOVED UP in the stack for proper layering
                Positioned.fill(
                  child: _TwoUpSwitch(repository: widget.repository),
                ),

                // WHEN premium and payment not done, show premium overlay that blocks video.
                if (isPremium && !_hasPaid)
                  Positioned.fill(
                    child: _PremiumBlockedOverlay(
                      fee: premiumFee,
                      isLoading: _premiumSheetLoading,
                      statusMessage: _premiumStatusMessage,
                      onOpenPayment: () async {
                        // open bottom sheet built inside this screen
                        if (numericLiveId == null) {
                          TopSnack.error(
                            context,
                            'Missing live id for payment.',
                          );
                          return;
                        }
                        await _showPremiumPaymentBottomSheet(
                          context,
                          liveId: numericLiveId,
                          fee: premiumFee,
                        );
                      },
                      onOpenWallet: () {
                        Navigator.of(context).pushNamed('/wallet');
                      },
                      onGuestViewAllowed: () {
                        // nothing; used if you want a trial view option (not implemented)
                      },
                    ),
                  ),

                // When not immersive, render the normal overlays. If _immersive is true,
                // we intentionally render nothing here (so only video remains visible).
                if (!_immersive) ...[
                  if (isPremium)
                    Positioned(
                      top: 40,
                      right: 5,
                      child: _PremiumBadge(
                        fee: premiumFee,
                        onTap: () {
                          // Show info sheet which on Unlock will trigger the payment sheet
                          _showPremiumInfoBottomSheet(
                            context,
                            fee: premiumFee,
                            onUnlock: () async {
                              if (numericLiveId == null) {
                                TopSnack.error(
                                  context,
                                  'Missing live id for payment.',
                                );
                                return;
                              }
                              // open the existing payment sheet you already wrote
                              await _showPremiumPaymentBottomSheet(
                                context,
                                liveId: numericLiveId,
                                fee: premiumFee,
                              );
                            },
                          );
                        },
                      ),
                    ),

                  // All other overlays - these should be above the video layout
                  const _TopStatusBar(),
                  const _TopicPill(),
                  const GiftOverlayLayer(), // animated gifts over video
                  const _GiftToast(),
                  const _HostCard(),
                  const _GuestJoinedBanner(),
                  const _GiftToast(),
                  const _PauseOverlay(), // handles global pause state
                  const _WaitingOverlay(),
                  const _RoleChangeToast(),

                  // Removal overlay
                  const _RemovalOverlay(),

                  // Error messages
                  const _ErrorToast(),

                  // Chat panel (bottom-left)
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
                          child: const _ChatPanel(),
                        ),
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _CommentBar(
                      controller: _commentCtrl,
                      onSend: (text) {
                        final t = text.trim();
                        if (t.isNotEmpty) {
                          context.read<ViewerBloc>().add(CommentSent(t));
                          _commentCtrl.clear();
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows bottom-sheet for premium payment, reusing the idempotency+retry approach.
  Future<void> _showPremiumPaymentBottomSheet(
    BuildContext context, {
    required int liveId,
    int? fee,
  }) async {
    final repo = sl<LiveFeedRepository>();
    final idempo = sl<IdempotencyHelper>();
    final uuid = const Uuid();

    bool isLoading = false;
    String? statusMessage;
    int? newBalance;

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void setLoading(bool v) => setState(() => isLoading = v);
            void setStatus(String? m) => setState(() => statusMessage = m);

            Future<void> payWithAutoNewIdempotency() async {
              const int maxAttempts = 5;
              final List<int> backoffMs = [0, 600, 1200, 2400, 4800];

              setLoading(true);
              setStatus(null);

              List<String> persistedKeys = [];
              for (int attempt = 0; attempt < maxAttempts; attempt++) {
                if (backoffMs.length > attempt && backoffMs[attempt] > 0) {
                  await Future.delayed(
                    Duration(milliseconds: backoffMs[attempt]),
                  );
                }

                final idempotencyKey = uuid.v4();

                try {
                  await idempo.persist(idempotencyKey, {
                    'liveId': liveId,
                    'attempt': attempt,
                  });
                  persistedKeys.add(idempotencyKey);
                } catch (e) {
                  TopSnack.info(
                    context,
                    'Warning: local persist failed for attempt ${attempt + 1}.',
                  );
                }

                try {
                  final resp = await repo.payPremium(
                    liveId: liveId,
                    idempotencyKey: idempotencyKey,
                  );

                  final status = (resp['status'] ?? '') as String;
                  final message = (resp['message'] as String?) ?? '';
                  final data = resp['data'] as Map<String, dynamic>?;

                  if (status.toLowerCase() == 'success') {
                    try {
                      await idempo.complete(idempotencyKey);
                    } catch (_) {}

                    for (final k in persistedKeys) {
                      if (k != idempotencyKey) {
                        try {
                          await idempo.complete(k);
                        } catch (_) {}
                      }
                    }

                    if (data != null && data['new_balance_coins'] != null) {
                      newBalance = (data['new_balance_coins'] as num).toInt();
                    }

                    TopSnack.success(
                      context,
                      data != null && data['message'] != null
                          ? data['message'] as String
                          : 'Premium paid successfully',
                    );

                    // Stop loading in sheet first
                    setLoading(false);

                    // Pop the sheet once and return a success result to caller
                    Navigator.of(context).pop(true);
                    return;
                  } else {
                    final lower = message.toLowerCase();
                    if (lower.contains('already processing') ||
                        lower.contains('processing')) {
                      if (attempt == maxAttempts - 1) {
                        setStatus(
                          'Request still processing. Please try again later.',
                        );
                        TopSnack.error(
                          context,
                          'Request still processing — try again later.',
                        );
                        break;
                      } else {
                        final nextAttempt = attempt + 1;
                        setStatus(
                          'Request already processing — retrying (attempt ${nextAttempt}/${maxAttempts})...',
                        );
                        TopSnack.info(
                          context,
                          'Request already processing — retrying (${nextAttempt}/${maxAttempts})',
                        );
                        continue;
                      }
                    } else if (lower.contains('insufficient')) {
                      setStatus(
                        'Insufficient coins. Open wallet to buy coins.',
                      );
                      TopSnack.error(context, 'Insufficient coins.');
                      break;
                    } else if (lower.contains('unauthorized') ||
                        lower.contains('unauth')) {
                      setStatus('You are not allowed to view this stream.');
                      TopSnack.error(context, 'This action is unauthorized.');
                      try {
                        await idempo.complete(idempotencyKey);
                      } catch (_) {}
                      break;
                    } else {
                      setStatus(
                        message.isNotEmpty ? message : 'Payment failed.',
                      );
                      TopSnack.error(
                        context,
                        message.isNotEmpty ? message : 'Payment failed.',
                      );
                      break;
                    }
                  }
                } catch (e) {
                  final nextAttempt = attempt + 1;
                  if (attempt == maxAttempts - 1) {
                    setStatus('Network error. Please try again later.');
                    TopSnack.error(
                      context,
                      'Network error. Please try again later.',
                    );
                    break;
                  } else {
                    setStatus(
                      'Network error — retrying (${nextAttempt}/${maxAttempts})...',
                    );
                    TopSnack.info(
                      context,
                      'Network error — retry ${nextAttempt}/${maxAttempts}',
                    );
                    continue;
                  }
                }
              } // for
              setLoading(false);
            } // payWithAutoNewIdempotency

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                top: 12,
              ),
              child: Material(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF0B0B0D),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 42,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                        ),
                        minLeadingWidth: 64,
                        leading: SizedBox(
                          width: 56,
                          height: 56,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        title: Text(
                          'Premium Access',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          'Unlock this stream to join and support the creator.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (fee != null)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.stars_rounded,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$fee coins',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Divider(
                              color: Colors.white.withOpacity(0.1),
                              thickness: 1,
                              height: 16,
                            ),
                            const SizedBox(height: 8),
                            if (statusMessage != null) ...[
                              Text(
                                statusMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : () async =>
                                              await payWithAutoNewIdempotency(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF7A00),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 6,
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Unlock Stream',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pushNamed('/wallet');
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.06),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Open Wallet',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (paid == true && mounted) {
      _onPremiumPaid();
    }
  }

  /// Bottom sheet explaining premium stream details. Uses onUnlock to trigger payment.
  Future<void> _showPremiumInfoBottomSheet(
    BuildContext context, {
    int? fee,
    required VoidCallback onUnlock,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              top: 12,
            ),
            child: Material(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF0B0B0D),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: Colors.white.withOpacity(.04),
                            width: 56,
                            height: 56,
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Colors.orangeAccent,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Premium Stream',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Exclusive access, direct support for the host, special badges and perks.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (fee != null)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(.04),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'You paid $fee coins to unlock this stream',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.06),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Called by the sheet on success to mark session as paid
  void _onPremiumPaid() {
    if (!mounted) return;
    setState(() {
      _hasPaid = true;
      _premiumSheetLoading = false;
      _premiumStatusMessage = null;
    });
  }
}

/// Background live video (or fallback image) + optional local preview bubble.
/// Background live video (or fallback image) + optional local preview bubble.
/// NOTE: prefer the repo instance from the ViewerBloc (if available) so UI uses
/// the same repo that the bloc subscribed/initialized.
class _BackgroundVideo extends StatelessWidget {
  final Widget child;
  final ViewerRepository repository;
  const _BackgroundVideo({required this.child, required this.repository});

  @override
  Widget build(BuildContext context) {
    // Prefer the repo used by the bloc (if present) — this avoids mismatch
    // when pager/bloc creates a different repo instance than widget.repository.
    final blocRepo = context.read<ViewerBloc>();

    final repoToUse = (blocRepo != null) ? blocRepo : repository;

    final videoProvider = repoToUse is VideoSurfaceProvider
        ? repoToUse as VideoSurfaceProvider
        : null;
    final localPreview = videoProvider?.buildLocalPreview();

    final fallback = Image.asset(
      'assets/images/onboard_1.jpg',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.network(
        'https://images.pexels.com/photos/414886/pexels-photo-414886.jpeg?auto=compress&w=800',
        fit: BoxFit.cover,
      ),
    );

    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.activeGuestUuid != n.activeGuestUuid ||
          p.currentRole != n.currentRole,
      builder: (context, s) {
        final iAmGuest = s.currentRole == 'guest' || s.currentRole == 'cohost';
        final anyGuest = s.activeGuestUuid != null || iAmGuest;

        // When in two-up mode, show black background and let _TwoUpSwitch handle videos
        if (anyGuest) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              child,
            ],
          );
        }

        // Normal single-host view
        return Stack(
          fit: StackFit.expand,
          children: [
            if (videoProvider == null)
              fallback
            else
              ValueListenableBuilder<bool>(
                valueListenable: videoProvider.hostHasVideo,
                builder: (_, hasVideo, __) =>
                    hasVideo ? videoProvider.buildHostVideo() : fallback,
              ),
            Container(color: Colors.black.withOpacity(0.15)),
            child,
            // Local preview bubble only when NOT in two-up mode AND not paused
            if (localPreview != null && !anyGuest && !s.isPaused)
              Positioned(right: 12, bottom: 150, child: localPreview),
          ],
        );
      },
    );
  }
}

class _ViewersListButton extends StatelessWidget {
  const _ViewersListButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.viewers != n.viewers,
      builder: (context, state) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            // Get the repository from Bloc to access livestream IDs
            final viewerBloc = context.read<ViewerBloc>();
            final repository = viewerBloc.repo;

            if (repository is ViewerRepositoryImpl) {
              // Use GetIt to access dependencies instead of context.read
              final dioClient = sl<DioClient>();
              final authLocalDataSource = sl<AuthLocalDataSource>();

              // Navigate to viewers list screen with livestream IDs and providers
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ViewersListScreen(
                    livestreamIdNumeric: repository.livestreamIdNumeric,
                    livestreamParam: repository.livestreamParam,
                    dioClient: dioClient,
                    authLocalDataSource: authLocalDataSource,
                  ),
                ),
              );
            }
          },
          child: _glass(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${state.viewers}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar();

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.elapsed != n.elapsed || p.viewers != n.viewers,
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              _glass(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.circle, color: Colors.redAccent, size: 10),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _glass(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    _fmt(state.elapsed),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const _ViewersListButton(),
            ],
          ),
        );
      },
    );
  }
}

class _TopicPill extends StatelessWidget {
  const _TopicPill();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.host != n.host,
      builder: (_, s) {
        final host = s.host;
        if (host == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 42),
            child: _glass(
              radius: 22,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Text(
                  host.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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

class _HostCard extends StatelessWidget {
  const _HostCard();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ViewerBloc>().repo;
    final HostUuid = (repo is ViewerRepositoryImpl)
        ? repo.hostUuid.toString()
        : '0';

    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.host != n.host,
      builder: (_, s) {
        final host = s.host;
        if (host == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 84),
          child: _glass(
            radius: 18,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        RouteNames.profileView,
                        arguments: {'userUuid': HostUuid, 'user_slug': ""},
                      );
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(host.avatarUrl),
                      radius: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                host.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  host.badge,
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        context.read<ViewerBloc>().add(const FollowToggled()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: host.isFollowed
                            ? Colors.black.withOpacity(.35)
                            : const Color(0xFFFF7A00),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        host.isFollowed ? 'Following' : 'Follow',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GuestJoinedBanner extends StatelessWidget {
  const _GuestJoinedBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.showGuestBanner != n.showGuestBanner || p.guest != n.guest,
      builder: (_, s) {
        if (!s.showGuestBanner || s.guest == null) {
          return const SizedBox.shrink();
        }
        final n = s.guest!;
        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 150),
            child: _glass(
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flight_takeoff_rounded,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${n.username} ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      n.message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
            child: _glass(
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

/// Ultra-modern chat panel with TikTok-inspired transparent design
class _ChatPanel extends StatefulWidget {
  const _ChatPanel();
  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _scrollController = ScrollController();
  bool _isAtTop = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final isAtTop = _scrollController.position.pixels == 0;
    if (isAtTop != _isAtTop) {
      setState(() {
        _isAtTop = isAtTop;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.chat != n.chat,
      builder: (_, s) {
        final chat = s.chat.reversed.toList();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, minWidth: 280),
          child: Container(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Stack(
                children: [
                  // Chat messages
                  ListView.separated(
                    controller: _scrollController,
                    reverse: true,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: chat.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m = chat[i];
                      return _ModernChatBubble(
                        username: m.username,
                        text: m.text,
                        isNew: i == 0,
                      );
                    },
                  ),

                  // Fade effect only at the top and only when not at top
                  if (!_isAtTop)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 100, // Height of the fade effect
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModernChatBubble extends StatelessWidget {
  final String username;
  final String text;
  final bool isHost;
  final bool isNew;

  const _ModernChatBubble({
    required this.username,
    required this.text,
    this.isHost = false,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(left: isNew ? 0 : 8, right: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isHost
              ? const Color(0xFFFF7A00).withOpacity(0.25)
              : Colors.black.withOpacity(0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User indicator dot
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 10, top: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHost
                      ? const Color(0xFFFF7A00)
                      : const Color(0xFF29C3FF),
                ),
              ),

              // Message content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username
                    Row(
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            color: isHost
                                ? const Color(0xFFFF7A00)
                                : const Color(0xFF29C3FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (isHost) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A00).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFF7A00).withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'HOST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Message text
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),

              // New message indicator
              if (isNew)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 8, top: 2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF7A00),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  const _CommentBar({required this.controller, required this.onSend});

  @override
  State<_CommentBar> createState() => _CommentBarState();
}

class _CommentBarState extends State<_CommentBar> {
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  void _sendMessage() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      widget.controller.clear();
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = false);
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _insertEmoji(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    widget.controller.text = newText;
    widget.controller.selection = selection.copyWith(
      baseOffset: selection.start + emoji.length,
      extentOffset: selection.start + emoji.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.showChatUI != n.showChatUI,
      builder: (context, s) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji picker (conditional)
              if (_showEmojiPicker) ...[
                _Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(12),
                  child: _EmojiGrid(onEmojiSelected: _insertEmoji),
                ),
                const SizedBox(height: 8),
              ],

              // Input row
              Row(
                children: [
                  // Expanded input field with transparent design
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.black.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Row(
                          children: [
                            // Emoji picker button
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: TextField(
                                  controller: widget.controller,
                                  focusNode: _focusNode,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Send a message...',
                                    hintStyle: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendMessage(),
                                  maxLines: 1,
                                ),
                              ),
                            ),

                            IconButton(
                              icon: Icon(
                                _showEmojiPicker
                                    ? Icons.keyboard_rounded
                                    : Icons.emoji_emotions_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 20,
                              ),
                              onPressed: _toggleEmojiPicker,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Action buttons with clean outline icons
                  Row(
                    children: [
                      // Chat toggle button
                      _ModernActionButton(
                        icon: s.showChatUI
                            ? Icons.chat_bubble_rounded
                            : Icons.chat_bubble_outline_rounded,
                        onTap: () {
                          context.read<ViewerBloc>().add(
                            s.showChatUI
                                ? const ChatHideRequested()
                                : const ChatShowRequested(),
                          );
                        },
                      ),
                      const SizedBox(width: 3),

                      // Gift button
                      _ModernActionButton(
                        icon: Icons.auto_awesome_rounded,
                        onTap: () async {
                          final bloc = context.read<ViewerBloc>();
                          bloc.add(const GiftSheetRequested());
                          final repo = context.read<ViewerBloc>().repo;
                          final livestreamId = (repo is ViewerRepositoryImpl)
                              ? repo.livestreamIdNumeric.toString()
                              : '0';
                          final toUserUuid = (repo is ViewerRepositoryImpl)
                              ? repo.hostUuid.toString()
                              : '0';
                          if (context.mounted) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => BlocProvider.value(
                                value: context.read<ViewerBloc>(),
                                child: GiftBottomSheet(
                                  toUserUuid: toUserUuid,
                                  livestreamId: livestreamId,
                                ),
                              ),
                            ).whenComplete(() {
                              if (context.mounted)
                                bloc.add(const GiftSheetClosed());
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 3),

                      // Send button
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A00).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  final Function(String) onEmojiSelected;

  final List<String> emojis = [
    '😂',
    '😍',
    '🥰',
    '😭',
    '😊',
    '👍',
    '❤️',
    '🔥',
    '🙏',
    '😎',
    '🎉',
    '💯',
    '🤔',
    '😢',
    '👏',
    '🙌',
    '😘',
    '🤣',
    '😅',
    '😡',
    '👀',
    '✨',
    '💕',
    '🎶',
  ];

  _EmojiGrid({required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => onEmojiSelected(emojis[index]),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.1),
            ),
            child: Center(
              child: Text(emojis[index], style: const TextStyle(fontSize: 20)),
            ),
          ),
        );
      },
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  const _Glass({
    required this.child,
    required this.padding,
    this.radius = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? Colors.black.withOpacity(0.35)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ModernActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ModernActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail();

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.likes != n.likes || p.shares != n.shares || p.chat != n.chat,
      builder: (_, s) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            _ModernRailButton(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () {
                context.read<ViewerBloc>().add(
                  s.showChatUI
                      ? const ChatHideRequested()
                      : const ChatShowRequested(),
                );
              },
              label: "",
              isActive: s.showChatUI,
            ),
            const SizedBox(height: 16),
            _ModernRailButton(
              icon: Icons.auto_awesome_rounded,
              onTap: () async {
                final bloc = context.read<ViewerBloc>();
                bloc.add(const GiftSheetRequested());
                final repo = context.read<ViewerBloc>().repo;
                final livestreamId = (repo is ViewerRepositoryImpl)
                    ? repo.livestreamIdNumeric.toString()
                    : '0';
                final toUserUuid = (repo is ViewerRepositoryImpl)
                    ? repo.hostUuid.toString()
                    : '0';
                if (context.mounted) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => BlocProvider.value(
                      value: context.read<ViewerBloc>(),
                      child: GiftBottomSheet(
                        toUserUuid: toUserUuid,
                        livestreamId: livestreamId,
                      ),
                    ),
                  ).whenComplete(() {
                    if (context.mounted) bloc.add(const GiftSheetClosed());
                  });
                }
              },
              label: "",
            ),
            const SizedBox(height: 16),
            _ModernRailButton(
              icon: Icons.favorite_outline_rounded,
              onTap: () => context.read<ViewerBloc>().add(const LikePressed()),
              label: _fmtCount(s.likes),
            ),
          ],
        );
      },
    );
  }
}

class _ModernRailButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final bool isActive;

  const _ModernRailButton({
    required this.icon,
    required this.onTap,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFFF7A00).withOpacity(0.2)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? const Color(0xFFFF7A00).withOpacity(0.5)
                    : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? const Color(0xFFFF7A00) : Colors.white,
              size: 20,
            ),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFFF7A00) : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _RequestToJoinButton extends StatelessWidget {
  const _RequestToJoinButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.joinRequested != n.joinRequested ||
          p.awaitingApproval != n.awaitingApproval,
      builder: (_, s) {
        if (s.joinRequested == true && s.awaitingApproval == false) {
          return const SizedBox.shrink();
        }

        final label = s.joinRequested == true ? 'Joined' : 'Join Stream';

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: s.joinRequested == true
              ? null
              : () => context.read<ViewerBloc>().add(
                  const RequestToJoinPressed(),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (s.joinRequested == true)
                const Icon(Icons.check, size: 18)
              else
                const Icon(Icons.video_call),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}

Widget _glass({required Widget child, double radius = 16, Color? color}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 4),
      child: Container(
        decoration: BoxDecoration(
          color: (color ?? Colors.black.withOpacity(.30)),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(.08), width: 1),
        ),
        child: child,
      ),
    ),
  );
}

class _PremiumBadge extends StatelessWidget {
  final int? fee;
  final VoidCallback? onTap; // open info sheet
  const _PremiumBadge({this.fee, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFC37A).withOpacity(0.1),
              const Color(0xFFFF7A00).withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fee != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      size: 12,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$fee',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.isPaused != n.isPaused || p.host != n.host,
      builder: (_, s) {
        if (!s.isPaused) return const SizedBox.shrink();
        final host = s.host;
        final handle = host == null
            ? ''
            : '@${host.name.replaceAll(' ', '_').toLowerCase()}';

        return IgnorePointer(
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2B2E83).withOpacity(0.55),
                  const Color(0xFF7B2F9B).withOpacity(0.55),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pause_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Stream Paused',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'The host has temporarily paused this livestream. Please stay tuned...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (host != null)
                  _glass(
                    radius: 22,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(host.avatarUrl),
                            radius: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            handle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Superstar',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withOpacity(.85),
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Leave Stream',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaitingOverlay extends StatelessWidget {
  const _WaitingOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.awaitingApproval != n.awaitingApproval,
      builder: (_, s) {
        if (!s.awaitingApproval) return const SizedBox.shrink();

        return IgnorePointer(
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2B2E83).withOpacity(0.55),
                  const Color(0xFF7B2F9B).withOpacity(0.55),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Connecting to stream...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleChangeToast extends StatelessWidget {
  const _RoleChangeToast();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.showRoleChangeToast != n.showRoleChangeToast,
      builder: (_, s) {
        if (!s.showRoleChangeToast || s.roleChangeMessage == null) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 120),
            child: _glass(
              radius: 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s.currentRole == 'guest' || s.currentRole == 'cohost'
                          ? Icons.star
                          : Icons.info,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      s.roleChangeMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RemovalOverlay extends StatelessWidget {
  const _RemovalOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.showRemovalOverlay != n.showRemovalOverlay,
      builder: (_, s) {
        if (!s.showRemovalOverlay) return const SizedBox.shrink();

        return IgnorePointer(
          child: Container(
            color: Colors.black.withOpacity(0.9),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, color: Colors.red, size: 64),
                const SizedBox(height: 20),
                Text(
                  s.removalReason ?? 'You have been removed from the stream',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Returning to home screen...',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorToast extends StatelessWidget {
  const _ErrorToast();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.errorMessage != n.errorMessage,
      builder: (context, state) {
        if (state.errorMessage?.isEmpty ?? true) {
          return const SizedBox.shrink();
        }
        return Positioned(
          top: 100,
          left: 20,
          right: 20,
          child: _glass(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () =>
                        context.read<ViewerBloc>().add(const ErrorOccurred('')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Renders the two-up tiles when either you are guest or there is an active guest.
class _TwoUpSwitch extends StatelessWidget {
  final ViewerRepository repository;
  const _TwoUpSwitch({required this.repository});

  @override
  Widget build(BuildContext context) {
    final vp = repository is VideoSurfaceProvider
        ? repository as VideoSurfaceProvider
        : null;
    if (vp == null) return const SizedBox.shrink();

    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.activeGuestUuid != n.activeGuestUuid ||
          p.currentRole != n.currentRole ||
          p.isPaused != n.isPaused,
      builder: (_, s) {
        final iAmGuest = s.currentRole == 'guest' || s.currentRole == 'cohost';
        final anyGuest = s.activeGuestUuid != null || iAmGuest;

        debugPrint(
          '🎯 TwoUpSwitch: iAmGuest=$iAmGuest, anyGuest=$anyGuest, activeGuestUuid=${s.activeGuestUuid}',
        );

        // Only show two-up layout when there's actually a guest
        if (!anyGuest) return const SizedBox.shrink();

        return IgnorePointer(
          ignoring: s.isPaused,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: vp.buildHostVideo()),
                    if (s.isPaused) _buildPauseOverlay(),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: iAmGuest
                          ? (vp.buildLocalPreview() ?? const SizedBox.shrink())
                          : vp.buildGuestVideo(),
                    ),
                    if (iAmGuest && !s.isPaused) const _GuestControls(),
                    if (s.isPaused) _buildPauseOverlay(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_filled, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text(
              'Stream Paused',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestControls extends StatefulWidget {
  const _GuestControls();
  @override
  State<_GuestControls> createState() => _GuestControlsState();
}

class _GuestControlsState extends State<_GuestControls> {
  bool micOn = false;
  bool camOn = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ViewerBloc>().repo;
    final vp = repo is VideoSurfaceProvider
        ? repo as VideoSurfaceProvider
        : null;
    if (vp == null) return const SizedBox.shrink();
    return Positioned(
      right: 12,
      bottom: 12,
      child: _glass(
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () async {
                  final next = !micOn;
                  setState(() => micOn = next);
                  await vp.setMicEnabled(next);
                },
                icon: Icon(
                  micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () async {
                  final next = !camOn;
                  setState(() => camOn = next);
                  await vp.setCamEnabled(next);
                },
                icon: Icon(
                  camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumBlockedOverlay extends StatelessWidget {
  final int? fee;
  final VoidCallback onOpenPayment;
  final VoidCallback onOpenWallet;
  final VoidCallback onGuestViewAllowed;
  final bool isLoading;
  final String? statusMessage;

  const _PremiumBlockedOverlay({
    this.fee,
    required this.onOpenPayment,
    required this.onOpenWallet,
    required this.onGuestViewAllowed,
    this.isLoading = false,
    this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // ignore pointer only when showing overlay; the overlay covers the entire view
      ignoring: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(.85),
              Colors.black.withOpacity(.92),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // sleek modern card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(.06)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 48,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Premium Stream',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This live stream is premium. Unlock access to view and support the host.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        if (fee != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.02),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$fee coins',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                        if (statusMessage != null)
                          Text(
                            statusMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isLoading ? null : onOpenPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF7A00),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Unlock',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: onOpenWallet,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.06),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                'Wallet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingInfoBubble extends StatelessWidget {
  final String text;
  const _FloatingInfoBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 8, 32, 248).withOpacity(.75),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.55),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: 0.4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 255, 122, 21).withOpacity(.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===================================================================
/// NEW: LiveViewerPager - TikTok-style vertical pager hosting LiveViewerScreen
/// ===================================================================

/// A vertical PageView that builds a ViewerRepositoryImpl for each LiveItem
/// on demand and hosts LiveViewerScreen pages.
class LiveViewerPager extends StatefulWidget {
  final List<LiveItem> items;
  final int initialIndex;

  const LiveViewerPager({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<LiveViewerPager> createState() => _LiveViewerPagerState();
}

class _LiveViewerPagerState extends State<LiveViewerPager> {
  late final PageController _pageController;
  final Map<int, ViewerRepositoryImpl> _repoCache = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    // pre-warm current repo
    _ensureRepoForIndex(_currentIndex);
  }

  @override
  void dispose() {
    for (final r in _repoCache.values) {
      try {
        r.dispose();
      } catch (_) {}
    }
    _repoCache.clear();
    _pageController.dispose();
    super.dispose();
  }

  ViewerRepositoryImpl _ensureRepoForIndex(int idx) {
    if (_repoCache.containsKey(idx)) return _repoCache[idx]!;
    final item = widget.items[idx];
    final repo = _buildRepositoryFromLiveItem(item);
    _repoCache[idx] = repo;
    return repo;
  }

  void _onPageChanged(int idx) {
    if (!mounted) return;
    setState(() => _currentIndex = idx);
    _ensureRepoForIndex(idx);
    // optional: dispose far away repos to conserve memory
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final repo = _ensureRepoForIndex(index);
          // Each page is a BlocProvider + LiveViewerScreen so blocs are local per page.
          return BlocProvider(
            create: (_) => ViewerBloc(repo)..add(const ViewerStarted()),
            child: LiveViewerScreen(repository: repo),
          );
        },
      ),
    );
  }
}

/// Helper to construct ViewerRepositoryImpl from a LiveItem using DI (sl)
ViewerRepositoryImpl _buildRepositoryFromLiveItem(LiveItem item) {
  final DioClient http = sl<DioClient>();
  final PusherService pusher = sl<PusherService>();
  final AuthLocalDataSource authLocalDataSource = sl<AuthLocalDataSource>();

  return ViewerRepositoryImpl(
    http: http,
    pusher: pusher,
    authLocalDataSource: authLocalDataSource,
    livestreamParam: item.uuid ?? item.id.toString(),
    livestreamIdNumeric: item.id,
    channelName: item.channel ?? '',
    hostUserUuid: item.hostUuid,
    initialHost: HostInfo(
      name: item.handle ?? 'Host',
      title: item.title ?? '',
      subtitle: '',
      badge: 'Superstar',
      avatarUrl: item.coverUrl ?? '',
      isFollowed: false,
    ),
    startedAt: item.startedAt != null
        ? DateTime.tryParse(item.startedAt!)
        : null,
  );
}
