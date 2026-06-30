// lib/features/live_viewer/presentation/pages/live_viewer_screen.dart
//
// REPLACEMENT. Two additions only vs the original:
//   1. Accepts optional `pool` (AgoraEnginePool) and `channelId` (String)
//      parameters. When both are present, passes them to the orchestrator
//      so it can render via PoolVideoView instead of the old single-engine
//      path. When absent (e.g. opened as a standalone route without the
//      pager) the screen falls back to the original AgoraViewerService
//      path — nothing breaks for single-stream opens.
//   2. Passes pool/channelId through to LiveViewerOrchestratorWrapper.
//
// EVERYTHING ELSE — premium gate, payment, BLoC lifecycle, swipe-back
// detection, fade placeholder, error screens — is byte-for-byte identical
// to the original. No functional changes to any of those paths.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/screens/live_viewer_orchestrator.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/repositories/viewer_repository.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/network_monitor_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/reconnection_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/role_change_service.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/live_loading_placeholder.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/overlays/premium_overlay.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:uuid/uuid.dart';

class LiveViewerScreen extends StatefulWidget {
  final ViewerRepository repository;
  final Map<String, dynamic>? routeArgs;

  // ── NEW optional pool params ─────────────────────────────────────────
  // Present when opened inside LiveViewerPager (pool-managed video).
  // Absent when opened as a standalone single-stream route (falls back
  // to the original AgoraViewerService path — no regression).
  final AgoraEnginePool? pool;
  final String? channelId;

  const LiveViewerScreen({
    super.key,
    required this.repository,
    this.routeArgs,
    this.pool,       // ← NEW (optional)
    this.channelId,  // ← NEW (optional)
  });

  factory LiveViewerScreen.create({
    required String livestreamId,
    required String channelName,
    String? hostUuid,
    HostInfo? hostInfo,
    DateTime? startedAt,
    Map<String, dynamic>? routeArgs,
  }) {
    final repository = createViewerRepository(
      livestreamParam: livestreamId,
      livestreamIdNumeric: int.tryParse(livestreamId) ?? 0,
      channelName: channelName,
      hostUserUuid: hostUuid,
      initialHost: hostInfo,
      startedAt: startedAt,
    );
    // No pool/channelId — standalone open, uses original Agora path.
    return LiveViewerScreen(repository: repository, routeArgs: routeArgs);
  }

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen>
    with SingleTickerProviderStateMixin {
  ViewerBloc? _startedBloc;
  ViewerBloc? _viewerBloc;
  bool _shouldStartBloc = false;

  final ValueNotifier<double> _videoReadyProgress = ValueNotifier(0.0);
  AnimationController? _fadeController;

  late PremiumVerificationState _premiumState;
  late bool _isPremiumStream;
  late int? _premiumFee;
  late int? _numericLiveId;
  bool _premiumCheckComplete = false;
  bool _isProcessingPayment = false;
  String? _paymentStatusMessage;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
      _videoReadyProgress.value = _fadeController!.value;
    });
    _initPremium();
  }

  @override
  void didUpdateWidget(LiveViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final repo = widget.repository;
    final wasReset = repo is ViewerRepositoryImpl && !repo.wasWired;
    if (widget.repository != oldWidget.repository || wasReset) {
      _startedBloc = null;
      _viewerBloc = null;
      _fadeController?.reset();
      _videoReadyProgress.value = 0;
      _initPremium();
    }
  }

  void _initPremium() {
    final args = widget.routeArgs ?? {};
    final rawIsPremium = args['isPremium'];
    _isPremiumStream =
        rawIsPremium == 1 || rawIsPremium == true || rawIsPremium == '1';
    _premiumFee = args['premiumFee'] as int?;
    _numericLiveId = args['id'] as int?;
    if (_isPremiumStream) {
      _premiumState = PremiumVerificationState.checking;
      _premiumCheckComplete = false;
      _shouldStartBloc = false;
      _checkPremiumStatus();
    } else {
      _premiumState = PremiumVerificationState.free;
      _premiumCheckComplete = true;
      _shouldStartBloc = true;
    }
  }

  void notifyVideoReady() {
    if (_fadeController == null || _fadeController!.isAnimating) return;
    if (_fadeController!.value >= 1.0) return;
    _fadeController!.forward();
  }

  Future<void> _checkPremiumStatus() async {
    if (_numericLiveId == null) {
      _markFreeAndProceed();
      return;
    }
    try {
      final response = await sl<LiveFeedRepository>().checkPremiumStatus(
        liveId: _numericLiveId!,
      );
      final data = (response['data'] as Map<String, dynamic>?) ?? {};
      final canAccess =
          data['can_access'] == true ||
          data['has_paid'] == true ||
          data['already_purchased'] == true;
      if (!mounted) return;
      setState(() {
        _premiumState = canAccess
            ? PremiumVerificationState.premiumPaid
            : PremiumVerificationState.premiumUnpaid;
        _premiumCheckComplete = true;
        _shouldStartBloc = canAccess;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _premiumState = PremiumVerificationState.error;
        _premiumCheckComplete = true;
        _shouldStartBloc = true;
      });
    }
  }

  void _markFreeAndProceed() {
    if (!mounted) return;
    setState(() {
      _premiumState = PremiumVerificationState.free;
      _premiumCheckComplete = true;
      _shouldStartBloc = true;
    });
  }

  Future<void> _processPremiumPayment(BuildContext context) async {
    if (_numericLiveId == null) return;
    setState(() {
      _isProcessingPayment = true;
      _paymentStatusMessage = null;
    });
    try {
      final response = await sl<LiveFeedRepository>().payPremium(
        liveId: _numericLiveId!,
        idempotencyKey: const Uuid().v4(),
      );
      final status = (response['status'] ?? '').toString().toLowerCase();
      final message = (response['message'] as String?) ?? '';
      if (!mounted) return;
      if (status == 'success') {
        setState(() {
          _isProcessingPayment = false;
          _premiumState = PremiumVerificationState.premiumPaid;
          _shouldStartBloc = true;
        });
        if (_viewerBloc != null && !_viewerBloc!.isClosed) {
          _viewerBloc!.add(const PremiumAccessGranted());
        }
        if (context.mounted) {
          TopSnack.success(context, 'Access unlocked! Enjoy the stream.');
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _viewerBloc != null && _startedBloc != _viewerBloc) {
            _viewerBloc!.add(const ViewerStarted());
            _startedBloc = _viewerBloc;
          }
        });
      } else {
        setState(() {
          _isProcessingPayment = false;
          _paymentStatusMessage = message.isNotEmpty
              ? message
              : 'Payment failed. Try again.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessingPayment = false;
        _paymentStatusMessage = 'Network error. Please try again.';
      });
    }
  }

  Widget _buildInitialPremiumGate(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PremiumOverlay(
        fee: _premiumFee,
        isLoading:
            _isProcessingPayment ||
            _premiumState == PremiumVerificationState.checking,
        statusMessage: _premiumState == PremiumVerificationState.checking
            ? null
            : _premiumState == PremiumVerificationState.error
            ? 'Could not verify access. Tap Retry.'
            : _paymentStatusMessage,
        onOpenPayment: _premiumState == PremiumVerificationState.error
            ? () {
                setState(() => _premiumState = PremiumVerificationState.checking);
                _checkPremiumStatus();
              }
            : () => _processPremiumPayment(context),
        onOpenWallet: () => Navigator.of(context).pushNamed('/wallet'),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _videoReadyProgress.dispose();
    _viewerBloc?.close();
    // Only call the old single-engine leave if NOT in pool mode.
    if (widget.pool == null) {
      try { sl<AgoraViewerService>().leave(); } catch (_) {}
    }
    widget.repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPremiumStream &&
        (_premiumState == PremiumVerificationState.checking ||
            _premiumState == PremiumVerificationState.premiumUnpaid ||
            _premiumState == PremiumVerificationState.error)) {
      return _buildInitialPremiumGate(context);
    }

    final args = widget.routeArgs ?? {};
    final hostAvatarUrl = args['hostAvatar'] as String?;
    final hostName = args['hostName'] as String?;

    if (!_premiumCheckComplete) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: LiveLoadingPlaceholder(avatarUrl: hostAvatarUrl, hostName: hostName),
      );
    }

    if (widget.repository is! ViewerRepositoryImpl) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Invalid repository type', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final repo = widget.repository as ViewerRepositoryImpl;

    final bloc = context.read<ViewerBloc>();
    _viewerBloc = bloc;

    if (_shouldStartBloc && _startedBloc != bloc && !bloc.isClosed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _startedBloc != bloc && !bloc.isClosed) {
          debugPrint('🚀 [Screen] Firing ViewerStarted on new bloc');
          bloc.add(const ViewerStarted());
          _startedBloc = bloc;
          _fadeController?.reset();
          _videoReadyProgress.value = 0;
        }
      });
    }

    return BlocListener<ViewerBloc, ViewerState>(
      listenWhen: (p, n) =>
          !p.requiresPremiumPayment && n.requiresPremiumPayment,
      listener: (ctx, state) {
        setState(() {
          _premiumState = PremiumVerificationState.premiumUnpaid;
          _isProcessingPayment = false;
          _paymentStatusMessage = null;
        });
        TopSnack.warning(
          ctx,
          'Host has made this stream premium. Unlock to continue watching.',
          duration: const Duration(seconds: 5),
        );
      },
      child: BlocBuilder<ViewerBloc, ViewerState>(
        buildWhen: (p, n) =>
            p.requiresPremiumPayment != n.requiresPremiumPayment ||
            p.status != n.status,
        builder: (ctx, state) {
          if (state.requiresPremiumPayment) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: PremiumOverlay(
                fee: state.premiumEntryFeeCoins ?? _premiumFee,
                isLoading: _isProcessingPayment,
                statusMessage: _paymentStatusMessage,
                onOpenPayment: () => _processPremiumPayment(ctx),
                onOpenWallet: () => Navigator.of(ctx).pushNamed('/wallet'),
              ),
            );
          }

          if (state.status == ViewerStatus.loading &&
              (_fadeController?.value ?? 0) > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _fadeController?.reset();
                _videoReadyProgress.value = 0;
              }
            });
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Pass pool/channelId through to the orchestrator wrapper
              // so it knows whether to use PoolVideoView or the old path.
              LiveViewerOrchestratorWrapper(
                repository: repo,
                pool: widget.pool,
                channelId: widget.channelId,
              ),
              ValueListenableBuilder<double>(
                valueListenable: _videoReadyProgress,
                builder: (_, progress, __) {
                  if (progress >= 1.0) return const SizedBox.shrink();
                  return LiveLoadingPlaceholder(
                    avatarUrl: hostAvatarUrl,
                    hostName: hostName,
                    fadeOutProgress: progress,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class LiveViewerOrchestratorWrapper extends StatelessWidget {
  final ViewerRepositoryImpl repository;
  // ── NEW optional pool params (passed through from screen) ────────────
  final AgoraEnginePool? pool;
  final String? channelId;

  const LiveViewerOrchestratorWrapper({
    super.key,
    required this.repository,
    this.pool,
    this.channelId,
  });

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // In pool mode the AgoraViewerService singleton is NOT the one
      // joined to this stream — don't log its state as representative.
      if (pool == null) {
        final s = sl<AgoraViewerService>();
        debugPrint(
          '🎯 RTC (single): ${s.isJoined ? "Joined" : "Not Joined"} '
          'Ch: ${s.channelId}',
        );
      } else {
        final slot = pool!.slotFor(SlotPosition.current);
        debugPrint(
          '🎯 RTC (pool/current): ${slot?.state} ch=${slot?.channelId}',
        );
      }
    });

    final screenState = context.findAncestorStateOfType<_LiveViewerScreenState>();
    return LiveViewerOrchestrator(
      repository: repository,
      onVideoReady: screenState?.notifyVideoReady,
      pool: pool,           // ← NEW
      channelId: channelId, // ← NEW
    );
  }
}

enum PremiumVerificationState {
  checking,
  free,
  premiumPaid,
  premiumUnpaid,
  error,
}