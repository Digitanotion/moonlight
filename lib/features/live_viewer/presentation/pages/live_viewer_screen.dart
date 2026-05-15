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

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  bool _didAutoStartBloc = false;
  ViewerBloc? _viewerBloc;
  bool _shouldStartBloc = false;

  // ── Initial premium gate (shown BEFORE the BLoC starts) ─────────────────
  late PremiumVerificationState _premiumState;
  late bool _isPremiumStream;
  late int? _premiumFee;
  late int? _numericLiveId;
  bool _premiumCheckComplete = false;

  // ── Runtime premium payment UI (shared by initial gate + BLoC overlay) ──
  bool _isProcessingPayment = false;
  String? _paymentStatusMessage;

  @override
  void initState() {
    super.initState();

    final args = widget.routeArgs ?? {};

    // isPremium arrives as int (0/1) from LiveItem / route args.
    // Treat anything truthy as premium.
    final rawIsPremium = args['isPremium'];
    _isPremiumStream =
        rawIsPremium == 1 || rawIsPremium == true || rawIsPremium == '1';

    _premiumFee = args['premiumFee'] as int?;
    _numericLiveId = args['id'] as int?;

    debugPrint('=== PREMIUM DEBUG ===');
    debugPrint('isPremium raw: $rawIsPremium  parsed: $_isPremiumStream');
    debugPrint('premiumFee: $_premiumFee');
    debugPrint('numericLiveId: $_numericLiveId');
    debugPrint('=====================');

    if (_isPremiumStream) {
      _premiumState = PremiumVerificationState.checking;
      _checkPremiumStatus();
    } else {
      _premiumState = PremiumVerificationState.free;
      _premiumCheckComplete = true;
      _shouldStartBloc = true;
    }
  }

  // ── Initial premium check ────────────────────────────────────────────────

  Future<void> _checkPremiumStatus() async {
    if (_numericLiveId == null) {
      _markFreeAndProceed();
      return;
    }

    try {
      final liveFeedRepo = sl<LiveFeedRepository>();
      final response = await liveFeedRepo.checkPremiumStatus(
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

      debugPrint(
        '✅ Premium check: ${canAccess ? "Access granted" : "Payment required"}',
      );
    } catch (e) {
      debugPrint('❌ Premium check error: $e');
      if (!mounted) return;
      setState(() {
        _premiumState = PremiumVerificationState.error;
        _premiumCheckComplete = true;
        // On error, let them in — health service will re-check
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

  // ── Payment processing (used by both initial gate and runtime overlay) ───

  Future<void> _processPremiumPayment(BuildContext context) async {
    if (_numericLiveId == null) return;

    setState(() {
      _isProcessingPayment = true;
      _paymentStatusMessage = null;
    });

    try {
      final repo = sl<LiveFeedRepository>();
      final response = await repo.payPremium(
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

        // If BLoC is already running (runtime paywall), tell it access granted
        if (_viewerBloc != null && !_viewerBloc!.isClosed) {
          _viewerBloc!.add(const PremiumAccessGranted());
        }

        if (context.mounted) {
          TopSnack.success(context, 'Access unlocked! Enjoy the stream.');
        }

        // Start the BLoC now if it wasn't started yet
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _viewerBloc != null && !_didAutoStartBloc) {
            _viewerBloc!.add(const ViewerStarted());
            _didAutoStartBloc = true;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingPayment = false;
        _paymentStatusMessage = 'Network error. Please try again.';
      });
    }
  }

  // ── Build the initial premium gate (before BLoC starts) ─────────────────

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
                setState(() {
                  _premiumState = PremiumVerificationState.checking;
                });
                _checkPremiumStatus();
              }
            : () => _processPremiumPayment(context),
        onOpenWallet: () => Navigator.of(context).pushNamed('/wallet'),
      ),
    );
  }

  // ── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _viewerBloc?.close();
    try {
      sl<AgoraViewerService>().leave();
    } catch (e) {
      debugPrint('⚠️ Error leaving Agora on dispose: $e');
    }
    widget.repository.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── 1. Show initial premium gate before BLoC is running ────────────────
    final showInitialGate =
        _isPremiumStream &&
        (_premiumState == PremiumVerificationState.checking ||
            _premiumState == PremiumVerificationState.premiumUnpaid ||
            _premiumState == PremiumVerificationState.error);

    if (showInitialGate) {
      return _buildInitialPremiumGate(context);
    }

    // ── 2. Premium check still in flight, show loader ─────────────────────
    if (!_premiumCheckComplete) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
      );
    }

    // ── 3. Wrong repo type guard ───────────────────────────────────────────
    if (widget.repository is! ViewerRepositoryImpl) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Invalid repository type',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final repo = widget.repository as ViewerRepositoryImpl;

    // ── 4. Get or create BLoC (with all services) ─────────────────────────
    ViewerBloc bloc;
    try {
      final existing = context.read<ViewerBloc>();
      bloc = existing.repo == repo ? existing : _buildBloc(repo);
    } catch (_) {
      bloc = _buildBloc(repo);
    }

    if (_viewerBloc == null) {
      _viewerBloc = bloc;
    }

    // ── 5. Schedule BLoC start ─────────────────────────────────────────────
    if (_shouldStartBloc && !_didAutoStartBloc) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_didAutoStartBloc) {
          _viewerBloc!.add(const ViewerStarted());
          _didAutoStartBloc = true;
        }
      });
    }

    // ── 6. Render the viewer with a runtime premium listener ───────────────
    return BlocProvider.value(
      value: bloc,
      child: BlocListener<ViewerBloc, ViewerState>(
        // Listen for runtime premium changes (host makes stream premium mid-session)
        listenWhen: (p, n) =>
            !p.requiresPremiumPayment && n.requiresPremiumPayment,
        listener: (ctx, state) {
          // Reset any stale payment messages
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
          // Rebuild when runtime premium paywall state changes
          buildWhen: (p, n) =>
              p.requiresPremiumPayment != n.requiresPremiumPayment,
          builder: (ctx, state) {
            // ── Runtime premium paywall (host made stream premium mid-session)
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

            // ── Normal viewer
            return const LiveViewerOrchestratorWrapper();
          },
        ),
      ),
    );
  }

  ViewerBloc _buildBloc(ViewerRepositoryImpl repo) {
    return ViewerBloc(
      repo,
      agoraViewerService: sl<AgoraViewerService>(),
      liveStreamService: sl<LiveStreamService>(),
      networkMonitorService: sl<NetworkMonitorService>(),
      reconnectionService: sl<ReconnectionService>(),
      roleChangeService: sl<RoleChangeService>(),
    );
  }
}

// ── Orchestrator wrapper ──────────────────────────────────────────────────────
class LiveViewerOrchestratorWrapper extends StatelessWidget {
  const LiveViewerOrchestratorWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ViewerBloc>();
    final repo = bloc.repo;

    if (repo is! ViewerRepositoryImpl) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Repository not compatible with new architecture',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final agoraService = sl<AgoraViewerService>();
      debugPrint(
        '🎯 RTC Status: ${agoraService.isJoined ? "Joined" : "Not Joined"}',
      );
      debugPrint(
        '🎯 Engine: ${agoraService.engine != null ? "Exists" : "NULL"}',
      );
      debugPrint('🎯 Channel: ${agoraService.channelId}');
    });

    return LiveViewerOrchestrator(repository: repo);
  }
}

enum PremiumVerificationState {
  checking,
  free,
  premiumPaid,
  premiumUnpaid,
  error,
}
