// lib/features/live_viewer/presentation/pages/live_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
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

  const LiveViewerScreen({super.key, required this.repository, this.routeArgs});

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
    return LiveViewerScreen(repository: repository, routeArgs: routeArgs);
  }

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen>
    with SingleTickerProviderStateMixin {
  // Track IDENTITY of the last BLoC we started.
  // When a new BLoC is created (swipe-back), this != bloc and we re-fire ViewerStarted.
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
    _fadeController =
        AnimationController(
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
    // Detect repo reset after swipe-back (keepAlive dispose resets _wired=false)
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
        if (_viewerBloc != null && !_viewerBloc!.isClosed)
          _viewerBloc!.add(const PremiumAccessGranted());
        if (context.mounted)
          TopSnack.success(context, 'Access unlocked! Enjoy the stream.');
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
                setState(
                  () => _premiumState = PremiumVerificationState.checking,
                );
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
    try {
      sl<AgoraViewerService>().leave();
    } catch (_) {}
    // When keepAlive=true this is a soft dispose: sends /leave, resets
    // wiring flags, keeps stream controllers open for swipe-back reuse.
    widget.repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Initial premium gate
    if (_isPremiumStream &&
        (_premiumState == PremiumVerificationState.checking ||
            _premiumState == PremiumVerificationState.premiumUnpaid ||
            _premiumState == PremiumVerificationState.error)) {
      return _buildInitialPremiumGate(context);
    }

    final args = widget.routeArgs ?? {};
    final hostAvatarUrl = args['hostAvatar'] as String?;
    final hostName = args['hostName'] as String?;

    // 2. Premium check in flight
    if (!_premiumCheckComplete) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: LiveLoadingPlaceholder(
          avatarUrl: hostAvatarUrl,
          hostName: hostName,
        ),
      );
    }

    // 3. Repo must be ViewerRepositoryImpl
    if (widget.repository is! ViewerRepositoryImpl) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Invalid repository type',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    final repo = widget.repository as ViewerRepositoryImpl;

    // 4. Get the BLoC from context (provided by pager's BlocProvider)
    final bloc = context.read<ViewerBloc>();
    _viewerBloc = bloc;

    // 5. Fire ViewerStarted whenever a NEW bloc is detected.
    //    _startedBloc tracks identity — on swipe-back, BlocProvider creates
    //    a fresh ViewerBloc so _startedBloc != bloc and we fire again.
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

    // 6. Main viewer
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
              LiveViewerOrchestratorWrapper(repository: repo),
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
  const LiveViewerOrchestratorWrapper({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = sl<AgoraViewerService>();
      debugPrint(
        '🎯 RTC: ${s.isJoined ? "Joined" : "Not Joined"} Engine: ${s.engine != null ? "OK" : "NULL"} Ch: ${s.channelId}',
      );
    });
    final screenState = context
        .findAncestorStateOfType<_LiveViewerScreenState>();
    return LiveViewerOrchestrator(
      repository: repository,
      onVideoReady: screenState?.notifyVideoReady,
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
