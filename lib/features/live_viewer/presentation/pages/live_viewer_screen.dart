import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/gifts/presentation/gift_bottom_sheet.dart';
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
import 'package:uuid/uuid.dart';

/// Legacy screen - maintained for backward compatibility
/// Now delegates to the new LiveViewerOrchestrator
class LiveViewerScreen extends StatefulWidget {
  final ViewerRepository repository;
  final Map<String, dynamic>? routeArgs; // ADD THIS

  const LiveViewerScreen({
    super.key,
    required this.repository,
    this.routeArgs, // ADD THIS
  });

  // Helper constructor for easy creation (Add this)
  factory LiveViewerScreen.create({
    required String livestreamId,
    required String channelName,
    String? hostUuid,
    HostInfo? hostInfo,
    DateTime? startedAt,
    Map<String, dynamic>? routeArgs, // ADD THIS
  }) {
    final repository = createViewerRepository(
      livestreamParam: livestreamId,
      livestreamIdNumeric: int.tryParse(livestreamId) ?? 0,
      channelName: channelName,
      hostUserUuid: hostUuid,
      initialHost: hostInfo,
      startedAt: startedAt,
    );

    return LiveViewerScreen(
      repository: repository,
      routeArgs: routeArgs, // PASS ROUTE ARGS
    );
  }

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  bool _didAutoStartBloc = false;
  // ADD PREMIUM STATE VARIABLES
  late PremiumVerificationState _premiumState;
  late bool _isPremiumStream;
  late int? _premiumFee;
  late int? _numericLiveId;
  bool _isProcessingPayment = false;
  String? _paymentStatusMessage;
  bool _premiumCheckComplete = false;
  ViewerBloc? _viewerBloc;
  bool _shouldStartBloc = false; // Add this flag

  @override
  void initState() {
    super.initState();

    // EXTRACT PREMIUM INFO FROM ROUTE ARGS
    final routeArgs = widget.routeArgs ?? {};
    _isPremiumStream = routeArgs['isPremium'] == 1;
    _premiumFee = routeArgs['premiumFee'] as int?;
    _numericLiveId = routeArgs['id'] as int?;

    debugPrint('=== PREMIUM DEBUG ===');
    debugPrint('Route args: $routeArgs');
    debugPrint('isPremium from args: ${routeArgs['isPremium']}');
    debugPrint('_isPremiumStream: $_isPremiumStream');
    debugPrint('premiumFee: $_premiumFee');
    debugPrint('numericLiveId: $_numericLiveId');
    debugPrint('channel: ${routeArgs['channel']}');
    debugPrint('=====================');

    // Initialize premium verification state
    _premiumState = _isPremiumStream
        ? PremiumVerificationState.checking
        : PremiumVerificationState.free;

    // Check premium status if needed
    if (_isPremiumStream) {
      debugPrint('⚠️ Premium stream detected, checking status...');
      _checkPremiumStatus();
    } else {
      debugPrint('✅ Free stream, proceeding normally');
      _premiumCheckComplete = true;
      _shouldStartBloc = true; // Set flag instead of accessing BLoC
    }
  }

  Future<void> _checkPremiumStatus() async {
    if (!_isPremiumStream || _numericLiveId == null) {
      setState(() {
        _premiumState = PremiumVerificationState.free;
        _premiumCheckComplete = true;
        _shouldStartBloc = true; // Set flag
      });
      return;
    }

    try {
      final liveFeedRepo = sl<LiveFeedRepository>();
      final response = await liveFeedRepo.checkPremiumStatus(
        liveId: _numericLiveId!,
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final canAccess =
          data['can_access'] == true ||
          data['has_paid'] == true ||
          data['already_purchased'] == true;

      setState(() {
        _premiumState = canAccess
            ? PremiumVerificationState.premiumPaid
            : PremiumVerificationState.premiumUnpaid;
        _premiumCheckComplete = true;
        _shouldStartBloc = canAccess; // Set flag based on access
      });

      debugPrint(
        '✅ Premium check result: ${canAccess ? "Access granted" : "Payment required"}',
      );
    } catch (e) {
      setState(() {
        _premiumState = PremiumVerificationState.error;
        _premiumCheckComplete = true;
      });
      debugPrint('❌ Error checking premium status: $e');
    }
  }

  // ADD PAYMENT PROCESSING METHOD
  Future<void> _processPremiumPayment() async {
    if (_numericLiveId == null) {
      debugPrint('❌ Missing live ID for payment');
      return;
    }

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

      final status = (response['status'] ?? '') as String;
      final message = (response['message'] as String?) ?? '';

      if (status.toLowerCase() == 'success') {
        debugPrint('✅ Premium payment successful');
        setState(() {
          _isProcessingPayment = false;
          _premiumState = PremiumVerificationState.premiumPaid;
          _shouldStartBloc = true; // Set flag after payment
        });

        // Trigger BLoC start in next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_viewerBloc != null && mounted) {
            _viewerBloc!.add(const ViewerStarted());
          }
        });
      } else {
        setState(() {
          _isProcessingPayment = false;
          _paymentStatusMessage = message.isNotEmpty
              ? message
              : 'Payment failed';
        });
        debugPrint('❌ Premium payment failed: $message');
      }
    } catch (e) {
      setState(() {
        _isProcessingPayment = false;
        _paymentStatusMessage = 'Network error: $e';
      });
      debugPrint('❌ Premium payment error: $e');
    }
  }

  // ADD PREMIUM OVERLAY WIDGET
  Widget _buildPremiumOverlay() {
    return Container(
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
                        _premiumState == PremiumVerificationState.checking
                            ? Icons.hourglass_empty
                            : Icons.lock_rounded,
                        size: 48,
                        color:
                            _premiumState == PremiumVerificationState.checking
                            ? Colors.blueAccent
                            : Colors.orangeAccent,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _premiumState == PremiumVerificationState.checking
                            ? 'Checking Access...'
                            : 'Premium Stream',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_premiumState == PremiumVerificationState.checking)
                        const Text(
                          'Verifying your access to this stream...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        )
                      else
                        const Text(
                          'This live stream is premium. Unlock access to view and support the host.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),

                      if (_premiumFee != null) ...[
                        const SizedBox(height: 18),
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
                                '$_premiumFee coins',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_paymentStatusMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _paymentStatusMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],

                      const SizedBox(height: 6),

                      if (_premiumState == PremiumVerificationState.checking)
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.orange,
                          ),
                        )
                      else if (_premiumState ==
                          PremiumVerificationState.premiumUnpaid)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isProcessingPayment
                                    ? null
                                    : _processPremiumPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF7A00),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isProcessingPayment
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Unlock Stream',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/wallet');
                              },
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
                                'Open Wallet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (_premiumState == PremiumVerificationState.error)
                        OutlinedButton(
                          onPressed: _checkPremiumStatus,
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
                            'Retry',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose the BLoC if it was created
    _viewerBloc?.close();

    final agoraService = sl<AgoraViewerService>();
    try {
      agoraService.leave();
    } catch (e) {
      debugPrint('⚠️ Error leaving Agora in screen dispose: $e');
    }

    widget.repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if we should show premium overlay
    final shouldShowPremiumOverlay =
        _isPremiumStream &&
        (_premiumState == PremiumVerificationState.premiumUnpaid ||
            _premiumState == PremiumVerificationState.checking ||
            _premiumState == PremiumVerificationState.error);

    if (shouldShowPremiumOverlay) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildPremiumOverlay(),
      );
    }

    // If premium check is not complete yet, show loading
    if (!_premiumCheckComplete) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
      );
    }

    // Ensure we have the right repository type
    if (widget.repository is! ViewerRepositoryImpl) {
      return Scaffold(
        body: Center(
          child: Text(
            'Invalid repository type',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final repo = widget.repository as ViewerRepositoryImpl;

    // Use the enhanced BLoC with services if available
    final existingBloc = context.read<ViewerBloc>();
    final bloc = existingBloc.repo == repo
        ? existingBloc
        : ViewerBloc(
            repo,
            agoraViewerService: sl<AgoraViewerService>(),
            liveStreamService: sl<LiveStreamService>(),
            networkMonitorService: sl<NetworkMonitorService>(),
            reconnectionService: sl<ReconnectionService>(),
            roleChangeService: sl<RoleChangeService>(),
          );

    // Store the BLoC if we created a new one
    if (_viewerBloc == null) {
      _viewerBloc = bloc;
    }

    // Trigger BLoC start if flag is set and not already started
    if (_shouldStartBloc && !_didAutoStartBloc && _viewerBloc != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _viewerBloc != null) {
          _viewerBloc!.add(const ViewerStarted());
          _didAutoStartBloc = true;
        }
      });
    }

    return BlocProvider.value(
      value: bloc,
      child: const LiveViewerOrchestratorWrapper(),
    );
  }
}

/// Wrapper that provides BLoC to the orchestrator
class LiveViewerOrchestratorWrapper extends StatelessWidget {
  const LiveViewerOrchestratorWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ViewerBloc>();
    final repo = bloc.repo;

    if (repo is! ViewerRepositoryImpl) {
      return Scaffold(
        body: Center(
          child: Text(
            'Repository not compatible with new architecture',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // Check if RTC is initialized (Add this debug check)
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
