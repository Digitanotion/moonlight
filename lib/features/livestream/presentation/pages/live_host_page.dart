// FILE: lib/features/livestream/presentation/pages/live_host_page.dart

import 'dart:async';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/config/runtime_config.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';
import 'package:moonlight/features/livestream/data/models/live_session_models.dart';
import 'package:moonlight/features/livestream/data/repositories/live_session_repository_impl.dart';
import 'package:moonlight/features/livestream/data/repositories/participants_repository_impl.dart';
import 'package:moonlight/features/livestream/domain/entities/live_join_request.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';
import 'package:moonlight/features/livestream/domain/repositories/participants_repository.dart';
import 'package:moonlight/features/livestream/domain/session/live_session_tracker.dart';
import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';
import 'package:moonlight/features/livestream/presentation/bloc/participants_bloc.dart';
import 'package:moonlight/features/livestream/presentation/pages/live_gifts_page.dart';
import 'package:moonlight/features/livestream/presentation/widgets/confirm_end_stream.dart';
import 'package:moonlight/features/livestream/presentation/widgets/gift_toast.dart';
import 'package:moonlight/features/livestream/presentation/widgets/live_settings_menu.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:moonlight/features/livestream/data/models/premium_package_model.dart';
import 'package:moonlight/features/livestream/data/models/wallet_model.dart';

class LiveHostPage extends StatefulWidget {
  final String hostName;
  final String hostBadge;
  final String topic;
  final int initialViewers;
  final String startedAtIso;
  final String? avatarUrl;
  final String? hostUuid;

  const LiveHostPage({
    super.key,
    required this.hostName,
    required this.hostBadge,
    required this.topic,
    required this.initialViewers,
    required this.startedAtIso,
    this.avatarUrl,
    this.hostUuid,
  });

  @override
  State<LiveHostPage> createState() => _LiveHostPageState();
}

class _LiveHostPageState extends State<LiveHostPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _initErr = false;
  bool _isPusherInitialized = false;
  bool _isPusherInitializing = false;
  final AgoraService agora = GetIt.I<AgoraService>();
  final LiveSessionRepositoryImpl _repoImpl =
      GetIt.I<LiveSessionRepository>() as LiveSessionRepositoryImpl;

  // Gift animation
  StreamSubscription<HostGiftBroadcast>? _giftBroadcastSub;
  final List<HostGiftBroadcast> _giftQueue = [];
  HostGiftBroadcast? _currentGift;
  Widget? _currentGiftWidget;
  AnimationController? _giftAnimController;
  bool _isPlayingGift = false;
  int _overflowCount = 0;
  static const int _maxQueueCap = 10;

  // Audio/Video controls
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _showSettingsMenu = false;
  bool _immersive = false;

  // Beauty effects
  bool _faceCleanEnabled = false;
  int _faceCleanLevel = 40;
  bool _brightenEnabled = false;
  int _brightenLevel = 40;

  // Connection management
  StreamSubscription<ConnectionState>? _pusherConnectionSub;
  ValueChanged<ConnectionState>? _connectionListener;
  bool _beautyAppliedOnJoin = false;

  GiftToast? _giftToast;

  @override
  void initState() {
    super.initState();
    _giftToast = GiftToast();
    WidgetsBinding.instance.addObserver(this);

    // Add listener for Agora state changes
    agora.addListener(_onAgoraStateChanged);
    // Prevent screen from sleeping during live stream
    WakelockPlus.enable();

    // Initialize Pusher and setup listeners
    _initializePusher();
  }

  void _onAgoraStateChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when audio/video state changes
      });
    }
  }

  Future<void> _initializePusher() async {
    if (_isPusherInitialized || _isPusherInitializing) {
      return;
    }

    _isPusherInitializing = true;

    try {
      final pusher = GetIt.I<PusherService>();
      final cfg = GetIt.I<RuntimeConfig>();
      final authLocal = GetIt.I<AuthLocalDataSource>();

      debugPrint('🚀 Checking Pusher initialization...');

      // ONLY initialize if not already done
      if (!pusher.isInitialized) {
        final apiKey = cfg.pusherKey;
        final cluster = cfg.pusherCluster;

        if (apiKey.isEmpty) {
          throw Exception('Pusher API key is empty');
        }

        debugPrint('🔧 Initializing Pusher...');

        await pusher.initialize(
          apiKey: apiKey,
          cluster: cluster,
          authEndpoint: '${cfg.apiBaseUrl}/broadcasting/auth',
          authCallback: (channelName, socketId, options) async {
            try {
              final token = await authLocal.readToken();
              if (token == null || token.isEmpty) {
                throw Exception('No auth token');
              }

              debugPrint('🔐 Auth request for channel: $channelName');

              final dio = Dio();
              dio.options.headers['Authorization'] = 'Bearer $token';
              dio.options.headers['Accept'] = 'application/json';

              final response = await dio.post(
                '${cfg.apiBaseUrl}/broadcasting/auth',
                data: {'socket_id': socketId, 'channel_name': channelName},
                options: Options(headers: {'Content-Type': 'application/json'}),
              );

              debugPrint('✅ Auth response: ${response.statusCode}');
              return response.data;
            } catch (e) {
              debugPrint('❌ Pusher auth error: $e');
              rethrow;
            }
          },
        );
        debugPrint('✅ Pusher initialized');
      } else {
        debugPrint('✅ Pusher already initialized, skipping');
      }

      // Setup connection listener only
      _setupPusherConnectionListener();

      _isPusherInitialized = true;
      debugPrint('✅ Pusher ready for LiveHost');
    } catch (e, stack) {
      debugPrint('❌ Pusher initialization failed: $e\n$stack');
      _isPusherInitializing = false;

      // Don't throw - let the repository handle connection
      return;
    } finally {
      _isPusherInitializing = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Start live session - repository will handle Pusher connection
        context.read<LiveHostBloc>().add(
          LiveStarted(
            widget.topic,
            initialViewers: widget.initialViewers,
            startedAtIso: widget.startedAtIso,
          ),
        );
      }
    });
  }

  void _setupPusherConnectionListener() {
    final pusher = GetIt.I<PusherService>();

    void connectionListener(ConnectionState state) {
      debugPrint('📡 [LiveHost] Pusher Connection State: $state');

      if (!mounted) return;

      if (state == ConnectionState.connected) {
        debugPrint('🔄 Pusher reconnected (passive)');
      } else if (state == ConnectionState.disconnected ||
          state == ConnectionState.failed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            TopSnack.info(context, 'Connection lost. Reconnecting...');
          }
        });
      }
    }

    // Add the listener
    pusher.addConnectionListener(connectionListener);

    // Store it so we can remove it later
    _connectionListener = connectionListener;
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing LiveHostPage...');
    agora.removeListener(_onAgoraStateChanged);
    // Remove Pusher listener if it exists
    if (_connectionListener != null) {
      final pusher = GetIt.I<PusherService>();
      pusher.removeConnectionListener(_connectionListener!);
      debugPrint('✅ Removed Pusher connection listener');
    }

    // Cancel gift broadcast subscription
    _giftBroadcastSub?.cancel();
    debugPrint('✅ Cancelled gift broadcast subscription');

    // Stop and dispose animation controller
    _giftAnimController?.stop();
    _giftAnimController?.dispose();
    debugPrint('✅ Disposed gift animation controller');

    // Reset beauty effects
    try {
      agora.resetBeauty();
      debugPrint('✅ Reset Agora beauty effects');
    } catch (_) {}

    // Disable wakelock
    WakelockPlus.disable();
    debugPrint('✅ Disabled wakelock');

    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    // Reset flags
    _isPusherInitialized = false;
    _isPusherInitializing = false;

    super.dispose();
    debugPrint('✅ LiveHostPage disposed');
  }

  void _onGiftBroadcast(HostGiftBroadcast b) {
    // Ignore gifts from the host (if any)
    final hostUuid = sl<LiveSessionTracker>().current?.hostUuid;
    if (b.senderUuid.isNotEmpty &&
        hostUuid != null &&
        b.senderUuid == hostUuid) {
      return;
    }

    // Enqueue with cap
    if (_giftQueue.length >= _maxQueueCap && !_isPlayingGift) {
      _overflowCount++;
      return;
    }

    // If currently playing and same sender+gift within combo window, aggregate
    if (_isPlayingGift && _currentGift != null) {
      final window = Duration(milliseconds: b.comboWindowMs ?? 2000);
      if (b.senderUuid == _currentGift!.senderUuid &&
          b.giftCode == _currentGift!.giftCode &&
          b.timestamp.difference(_currentGift!.timestamp).abs() <= window) {
        setState(() {
          _currentGift!.quantity += b.quantity;
          _currentGift!.coinsSpent += b.coinsSpent;
        });
        return;
      }
    }

    _giftQueue.add(b);
    if (!_isPlayingGift) {
      _playNextGift();
    }
  }

  Future<void> _playNextGift() async {
    if (_isPlayingGift) return;
    if (_giftQueue.isEmpty) return;

    _currentGift = _giftQueue.removeAt(0);
    _overflowCount = _overflowCount > 0 ? _overflowCount - 1 : 0;
    _isPlayingGift = true;
    _currentGiftWidget = null;
    setState(() {});

    try {
      // Build art (may be async)
      _currentGiftWidget = await GiftVisuals.build(
        _currentGift!.giftCode,
        size: 84,
        title: _currentGift!.giftName,
        imageUrl: null,
      );
    } catch (e) {
      debugPrint('⚠️ GiftVisuals build failed: $e');
      _currentGiftWidget = const Icon(Icons.card_giftcard, size: 64);
    }

    // Determine durations
    final entranceMs = 350;
    final baseHoldMs = 1800;
    final exitMs = 250;
    final extraPerQuantity = 300;
    final holdMs =
        baseHoldMs +
        ((_currentGift!.quantity - 1).clamp(0, 4) * extraPerQuantity);
    final totalMs = entranceMs + holdMs + exitMs;

    _giftAnimController?.dispose();
    _giftAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    _giftAnimController!.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        // finish and dequeue
        setState(() {
          _currentGift = null;
          _currentGiftWidget = null;
          _isPlayingGift = false;
        });
        // small delay before next play to avoid tight loops
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) _playNextGift();
        });
      }
    });

    _giftAnimController!.forward();
    setState(() {});
  }

  double _evalEntrance(double t) => Curves.easeOutBack.transform(t);
  double _evalExit(double t) => Curves.easeIn.transform(t);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-enable wakelock when app comes to foreground
      WakelockPlus.enable();
    }
  }

  // Add mute control methods
  void _toggleAudioMute() {
    agora.setMicEnabled(!agora.isMicEnabled);
  }

  void _toggleVideoMute() {
    agora.setCameraEnabled(!agora.isCameraEnabled);
  }

  void _toggleSettingsMenu() {
    setState(() {
      _showSettingsMenu = !_showSettingsMenu;
    });
  }

  Future<void> _applyEffects() async {
    try {
      // Use the instance-level agora (declared earlier in this state)
      if (!agora.joined) {
        // Not joined yet; mark for re-apply on join
        _beautyAppliedOnJoin = false;
        if (kDebugMode)
          debugPrint('[Beauty] Engine not joined yet; pending apply');
        return;
      }

      // Compose request
      final faceOn = _faceCleanEnabled;
      final faceLevel = _faceCleanLevel.clamp(0, 100);
      final brightOn = _brightenEnabled;
      final brightLevel = _brightenLevel.clamp(0, 100);

      await agora.applyBeauty(
        faceCleanEnabled: faceOn,
        faceCleanLevel: faceLevel,
        brightenEnabled: brightOn,
        brightenLevel: brightLevel,
      );

      _beautyAppliedOnJoin = true;
      if (kDebugMode) {
        debugPrint(
          '[Beauty] applied face:$faceOn($faceLevel) bright:$brightOn($brightLevel)',
        );
      }
    } catch (e, st) {
      debugPrint('❌ Failed to apply beauty effects: $e\n$st');
    }
  }

  // Show a compact bottom sheet allowing toggle + slider for an effect
  void _showBeautyBottomSheet({required bool isFaceClean}) {
    // Hide the quick settings menu while the sheet is open
    if (_showSettingsMenu) {
      setState(() => _showSettingsMenu = false);
    }

    final title = isFaceClean ? 'Face Clean' : 'Brighten';
    final int currentLevel = isFaceClean ? _faceCleanLevel : _brightenLevel;
    final bool currentEnabled = isFaceClean
        ? _faceCleanEnabled
        : _brightenEnabled;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.40,
          minChildSize: 0.28,
          maxChildSize: 0.80,
          builder: (context, scrollCtrl) {
            return StatefulBuilder(
              builder: (sheetCtx, sheetSetState) {
                int innerLevel = currentLevel;
                bool innerEnabled = currentEnabled;

                return _Glass(
                  radius: 18,
                  padding: const EdgeInsets.all(12),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    ),
                    child: ListView(
                      controller: scrollCtrl,
                      shrinkWrap: true,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Switch(
                              value: innerEnabled,
                              onChanged: (v) {
                                sheetSetState(() => innerEnabled = v);
                              },
                              activeColor: const Color(0xFFFF6A00),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Intensity: ${innerLevel}%',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Slider(
                          min: 0,
                          max: 100,
                          divisions: 100,
                          value: innerLevel.toDouble(),
                          onChanged: (v) {
                            sheetSetState(() => innerLevel = v.round());
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Apply: update page-level state, dispatch to Bloc so persistence happens,
                                  // and close the sheet.
                                  setState(() {
                                    if (isFaceClean) {
                                      _faceCleanEnabled = innerEnabled;
                                      _faceCleanLevel = innerLevel;
                                    } else {
                                      _brightenEnabled = innerEnabled;
                                      _brightenLevel = innerLevel;
                                    }
                                  });

                                  // Dispatch to Bloc to persist + apply via bloc
                                  try {
                                    context.read<LiveHostBloc>().add(
                                      BeautyPreferencesUpdated(
                                        faceCleanEnabled: _faceCleanEnabled,
                                        faceCleanLevel: _faceCleanLevel,
                                        brightenEnabled: _brightenEnabled,
                                        brightenLevel: _brightenLevel,
                                      ),
                                    );
                                  } catch (e) {
                                    debugPrint(
                                      '⚠️ Failed to dispatch beauty update: $e',
                                    );
                                    // fallback: apply immediately (best-effort)
                                    _applyEffects();
                                  }

                                  Navigator.of(ctx).pop();
                                },
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6A00),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Apply',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Add this widget method for settings menu
  Widget _buildSettingsMenu() {
    return Positioned(
      right: 18,
      bottom: 80, // Position above the bottom actions
      child: AnimatedOpacity(
        opacity: _showSettingsMenu ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Visibility(
          visible: _showSettingsMenu,
          child: _Glass(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black.withOpacity(0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SettingsMenuItem(
                  icon: _isAudioMuted
                      ? Icons.mic_off_rounded
                      : Icons.mic_rounded,
                  label: _isAudioMuted ? 'Unmute Audio' : 'Mute Audio',
                  isActive: _isAudioMuted,
                  onTap: _toggleAudioMute,
                ),
                const SizedBox(height: 12),
                _SettingsMenuItem(
                  icon: _isVideoMuted
                      ? Icons.videocam_off_rounded
                      : Icons.videocam_rounded,
                  label: _isVideoMuted ? 'Show Video' : 'Hide Video',
                  isActive: _isVideoMuted,
                  onTap: _toggleVideoMute,
                ),
                const SizedBox(height: 12),
                _SettingsMenuItem(
                  icon: Icons.face_retouching_natural,
                  label: 'Face Clean',
                  isActive: _faceCleanEnabled,
                  onTap: () => _showBeautyBottomSheet(isFaceClean: true),
                ),
                const SizedBox(height: 8),
                _SettingsMenuItem(
                  icon: Icons.wb_sunny,
                  label: 'Brighten',
                  isActive: _brightenEnabled,
                  onTap: () => _showBeautyBottomSheet(isFaceClean: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _mmss(int total) {
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Use a simple Container instead of CircularProgressIndicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF6A00), width: 2),
            ),
            child: const Center(
              child: Icon(
                Icons.videocam_rounded,
                color: Color(0xFFFF6A00),
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Setting up your livestream...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          BlocBuilder<LiveHostBloc, LiveHostState>(
            builder: (context, state) {
              return Text(
                'Viewers: ${state.viewers} | Time: ${_mmss(state.elapsedSeconds)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agora = GetIt.I<AgoraService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: MultiBlocListener(
        listeners: [
          // 1) Navigate out when stream ends
          BlocListener<LiveHostBloc, LiveHostState>(
            listenWhen: (p, c) =>
                p.isLive != c.isLive || p.endAnalytics != c.endAnalytics,
            listener: (context, state) {
              if (!state.isLive) {
                // Prefer analytics route if present
                if (state.endAnalytics != null) {
                  Navigator.of(context).pushReplacementNamed(
                    RouteNames.livestreamEnded,
                    arguments: state.endAnalytics,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Live stream has ended'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(RouteNames.home, (r) => false);
                }
              }
            },
          ),
        ],
        child: BlocBuilder<LiveHostBloc, LiveHostState>(
          builder: (context, state) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v > 300) {
                  setState(() => _immersive = true);
                } else if (v < -300) {
                  setState(() => _immersive = false);
                }
              },
              child: Stack(
                children: [
                  // Camera preview
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: agora,
                      builder: (_, __) {
                        return Builder(
                          builder: (context) {
                            if (!agora.joined) {
                              if (!_beautyAppliedOnJoin) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _applyEffects();
                                });
                              }
                              return _buildLoadingState();
                            }

                            final hasGuestInBloc = context
                                .select<LiveHostBloc, bool>(
                                  (b) => b.state.activeGuestUuid != null,
                                );

                            final hasRemoteUid =
                                agora.primaryRemoteUid.value != null;
                            final remoteHasVideo = agora.remoteHasVideo;

                            debugPrint(
                              '🎥 Video State - Guest in BLoC: $hasGuestInBloc, '
                              'Remote UID: $hasRemoteUid, '
                              'Remote has video: $remoteHasVideo',
                            );

                            if (!hasGuestInBloc || !hasRemoteUid) {
                              // Single host view - full screen with elegant overlay
                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.zero,
                                      child: agora.localPreview(),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.1),
                                            Colors.black.withOpacity(0.3),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            // Modern two-up layout with host and guest
                            return Stack(
                              children: [
                                // Host video - main content (larger)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: _buildHostVideoWithOverlay(),
                                ),

                                // Guest video - floating panel (smaller)
                                _buildGuestVideoFloatingPanel(
                                  state.activeGuestName ?? 'Guest',
                                ),

                                // Connection status indicator
                                // if (!remoteHasVideo)
                                //   Positioned(
                                //     right: 16,
                                //     bottom:
                                //         100 +
                                //         MediaQuery.of(context).size.width *
                                //             0.35 *
                                //             1.77 +
                                //         8,
                                //     child: _buildConnectionStatus(),
                                //   ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Add this to your build method, after the Positioned.fill for camera preview
                  // ===== Top Bar (fixed alignment) =====
                  if (!_immersive) ...[
                    Positioned(
                      left: 12,
                      right: 12,
                      top: MediaQuery.of(context).padding.top + 8,
                      child: _HeaderBar(
                        hostName: widget.hostName,
                        hostBadge: widget.hostBadge,
                        avatarUrl: widget.avatarUrl,
                        timeText: _mmss(state.elapsedSeconds),
                        viewersText: _formatViewers(state.viewers),
                        onEnd: () {
                          // This will only be called after user confirms
                          try {
                            context.read<LiveHostBloc>().add(EndPressed());
                          } catch (e, stack) {
                            debugPrint('Button tap error: $e');
                            debugPrint('Stack: $stack');
                            TopSnack.error(context, 'Error ending stream: $e');
                          }

                          LiveSessionRepositoryImpl repo =
                              GetIt.I<LiveSessionRepositoryImpl>();
                          repo.safeEndSession();
                        },
                      ),
                    ),

                    // Connection status indicator
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: MediaQuery.of(context).size.width / 2 - 50,
                      child: BlocBuilder<LiveHostBloc, LiveHostState>(
                        builder: (context, state) {
                          final pusher = GetIt.I<PusherService>();
                          final isConnected = pusher.isConnected;

                          if (isConnected) return const SizedBox.shrink();

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Reconnecting...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Floating short Premium pill (top-right, above header)
                    if (state.isPremium)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 100,
                        right: 20,
                        child: GestureDetector(
                          onTap: _showCancelPremiumBottomSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.redAccent,
                                width: 1.25,
                              ),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Dim layer when paused
                    if (state.isPaused)
                      Positioned.fill(
                        child: Container(color: Colors.black.withOpacity(0.55)),
                      ),

                    // Topic chip
                    Positioned(
                      top: 92,
                      left: 12,
                      right: 12,
                      child: _Glass(
                        radius: 18,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Text(
                          widget.topic,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),

                    // Host Gift Overlay (top-center)
                    if (_currentGift != null && _giftAnimController != null)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 64,
                        left: 18,
                        right: 18,
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _giftAnimController!,
                            builder: (context, _) {
                              final t = _giftAnimController!.value;
                              final entrancePortion =
                                  350 /
                                  (_giftAnimController!
                                      .duration!
                                      .inMilliseconds);
                              final exitPortion =
                                  250 /
                                  (_giftAnimController!
                                      .duration!
                                      .inMilliseconds);
                              double opacity = 1.0;
                              double translateY = 0.0;
                              if (t < entrancePortion) {
                                final nt = t / entrancePortion;
                                opacity = nt;
                                translateY = 40 * (1 - _evalEntrance(nt));
                              } else if (t > (1 - exitPortion)) {
                                final nt =
                                    (t - (1 - exitPortion)) / exitPortion;
                                opacity = 1 - _evalExit(nt);
                                translateY = 20 * nt;
                              }

                              return Opacity(
                                opacity: opacity,
                                child: Transform.translate(
                                  offset: Offset(0, translateY),
                                  child: Center(
                                    child: _Glass(
                                      radius: 18,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Avatar
                                          Transform.scale(
                                            scale:
                                                0.9 +
                                                0.1 *
                                                    (t < 0.5 ? t * 2 : (1 - t)),
                                            child: CircleAvatar(
                                              radius: 22,
                                              backgroundImage:
                                                  _currentGift!.senderAvatar !=
                                                      null
                                                  ? NetworkImage(
                                                      _currentGift!
                                                          .senderAvatar!,
                                                    )
                                                  : const AssetImage(
                                                          'assets/images/logo.png',
                                                        )
                                                        as ImageProvider,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Texts
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '@${_currentGift!.senderDisplayName}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'sent ${_currentGift!.giftCode} to you',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 13.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFFF6A00,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '+${_currentGift!.coinsSpent}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Gift art
                                          Container(
                                            width: 84,
                                            height: 84,
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFFFF6A00,
                                                  ).withOpacity(.12),
                                                  blurRadius: 18,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child:
                                                _currentGiftWidget ??
                                                const SizedBox.shrink(),
                                          ),
                                          const SizedBox(width: 8),
                                          // multiplier badge if quantity > 1
                                          if ((_currentGift!.quantity) > 1)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white24,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'x${_currentGift!.quantity}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    // Join Request card
                    if (state.pendingRequest != null && !state.isPaused)
                      Positioned(
                        top: 120,
                        left: 16,
                        right: 16,
                        child: _JoinRequestCard(
                          req: state.pendingRequest!,
                          onAccept: () => context.read<LiveHostBloc>().add(
                            AcceptJoinRequest(state.pendingRequest!.id),
                          ),
                          onDecline: () => context.read<LiveHostBloc>().add(
                            DeclineJoinRequest(state.pendingRequest!.id),
                          ),
                        ),
                      ),

                    // Chat overlay - only show when chatVisible is true
                    if (state.chatVisible && !state.isPaused)
                      Positioned(
                        left: 7,
                        right: 7,
                        bottom: 100,
                        child: _HostChatWidget(
                          messages: state.messages,
                          onSendMessage: (text) {
                            context.read<LiveHostBloc>().add(
                              SendChatMessage(text),
                            );
                          },
                        ),
                      ),

                    // Bottom actions - with chat toggle button
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SafeArea(
                          top: false,
                          child: _BottomActions(
                            isPaused: state.isPaused,
                            onPause: () =>
                                context.read<LiveHostBloc>().add(TogglePause()),
                            onChatToggle: () => context
                                .read<LiveHostBloc>()
                                .add(ToggleChatVisibility()),
                            onGifts: () {
                              final tracker = sl<LiveSessionTracker>();
                              final numericId = tracker.current!.livestreamId;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LiveGiftsPage(livestreamId: numericId),
                                ),
                              );
                            },
                            onViewers: () {
                              final tracker = sl<LiveSessionTracker>();
                              final numericId = tracker.current!.livestreamId;
                              final restParam =
                                  '${tracker.current!.livestreamId}';

                              _registerParticipantsForCurrentSession();

                              Navigator.pushNamed(
                                context,
                                RouteNames.listViewers,
                              );
                            },
                            onPremium: _showPremiumBottomSheet,
                            onSettings: _toggleSettingsMenu,
                            agora: agora,
                          ),
                        ),
                      ),
                    ),

                    // Settings Menu - NEW
                    if (_showSettingsMenu)
                      LiveSettingsMenu(
                        onClose: () {
                          setState(() => _showSettingsMenu = false);
                        },
                        agora: agora,
                      ),

                    // Paused overlay
                    if (state.isPaused)
                      _PausedOverlay(
                        onResume: () =>
                            context.read<LiveHostBloc>().add(TogglePause()),
                      ),
                  ],

                  // Positioned(
                  //   top: MediaQuery.of(context).padding.top + 200,
                  //   right: 20,
                  //   child: GestureDetector(
                  //     onTap: () {
                  //       debugPrint('🧪 [UI TEST] Testing stream flow...');

                  //       // Test 1: Direct BLoC event
                  //       context.read<LiveHostBloc>().add(
                  //         IncomingMessage(
                  //           LiveChatMessage('@test', 'Direct test message'),
                  //         ),
                  //       );
                  //       debugPrint('✅ [UI TEST] Sent direct BLoC event');

                  //       // Test 2: Repository test
                  //       _repoImpl.testStreamControllers();

                  //       // Test 3: Simulate pause event
                  //       context.read<LiveHostBloc>().add(
                  //         PauseStatusChanged(true),
                  //       );
                  //       debugPrint('✅ [UI TEST] Sent pause event');

                  //       // Test 4: Check current state
                  //       final state = context.read<LiveHostBloc>().state;
                  //       debugPrint('📊 [UI TEST] Current state:');
                  //       debugPrint('  - Viewers: ${state.viewers}');
                  //       debugPrint('  - Messages: ${state.messages.length}');
                  //       debugPrint('  - Paused: ${state.isPaused}');
                  //       debugPrint('  - Chat visible: ${state.chatVisible}');
                  //     },
                  //     child: Container(
                  //       padding: const EdgeInsets.all(12),
                  //       decoration: BoxDecoration(
                  //         color: Colors.blue,
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //       child: const Row(
                  //         mainAxisSize: MainAxisSize.min,
                  //         children: [
                  //           Icon(
                  //             Icons.bug_report,
                  //             color: Colors.white,
                  //             size: 16,
                  //           ),
                  //           SizedBox(width: 8),
                  //           Text(
                  //             'TEST',
                  //             style: TextStyle(
                  //               color: Colors.white,
                  //               fontSize: 12,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  if (!_immersive) GiftToast(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _registerParticipantsForCurrentSession() {
    try {
      final tracker = GetIt.I<LiveSessionTracker>();
      final current = tracker.current;

      if (current == null) {
        debugPrint('⚠️ No live session found for participants registration');
        return;
      }

      final numericId = current.livestreamId;
      final restParam = current.livestreamId.toString();

      debugPrint('🔧 Registering participants for livestream ID: $numericId');

      // Check if we're already registered for this session
      if (GetIt.I.isRegistered<ParticipantsRepository>()) {
        try {
          final existingRepo = GetIt.I<ParticipantsRepository>();
          // Check if it's the same session
          if (existingRepo is ParticipantsRepositoryImpl) {
            if (existingRepo.livestreamIdNumeric == numericId) {
              debugPrint('✅ Participants already registered for this session');
              return;
            }
          }

          // Different session - clean up
          GetIt.I<ParticipantsRepository>().dispose();
        } catch (_) {}
        GetIt.I.unregister<ParticipantsRepository>();
      }

      // Register new repository with current session
      GetIt.I.registerLazySingleton<ParticipantsRepository>(
        () => ParticipantsRepositoryImpl(
          GetIt.I<DioClient>(),
          GetIt.I<PusherService>(),
          livestreamIdNumeric: numericId,
          livestreamParam: restParam,
        ),
      );

      // Update ParticipantsBloc
      if (GetIt.I.isRegistered<ParticipantsBloc>()) {
        GetIt.I.unregister<ParticipantsBloc>();
      }

      GetIt.I.registerFactory<ParticipantsBloc>(
        () => ParticipantsBloc(GetIt.I<ParticipantsRepository>()),
      );

      debugPrint('✅ Registered participants for livestream ID: $numericId');
    } catch (e, stack) {
      debugPrint('❌ Failed to register participants: $e\n$stack');
    }
  }

  // ===== Premium BottomSheet (open when host taps "Premiums" button) =====
  void _showPremiumBottomSheet() {
    final liveHostBloc = context.read<LiveHostBloc>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          builder: (context, scrollCtrl) {
            return _PremiumBottomSheet(
              scrollController: scrollCtrl,
              repo: _repoImpl,
              onActivate: (PremiumPackageModel pkg) {
                liveHostBloc.add(ActivatePremium(pkg));
                Navigator.of(context).pop();
              },
            );
          },
        );
      },
    );
  }

  // ===== Cancel Premium BottomSheet (open when host taps premium badge) =====
  void _showCancelPremiumBottomSheet() {
    final liveHostBloc = context.read<LiveHostBloc>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.32,
          minChildSize: 0.2,
          maxChildSize: 0.6,
          builder: (sheetCtx, scrollCtrl) {
            return _CancelPremiumSheet(
              scrollController: scrollCtrl,
              onConfirm: () {
                liveHostBloc.add(CancelPremium());
                Navigator.of(sheetCtx).pop();
              },
            );
          },
        );
      },
    );
  }

  static void _toast(BuildContext c, String title) {
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(
        content: Text('$title coming soon'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatViewers(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }

  Widget _buildHostVideoWithOverlay() {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.zero, child: agora.localPreview()),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.2)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestVideoFloatingPanel(String guestName) {
    // Add these new variables to track drag position
    final double panelWidth = MediaQuery.of(context).size.width * 0.40;
    final double panelHeight = panelWidth * 1.77;

    // Use a stateful wrapper to manage drag position
    return _DraggableGuestVideoPanel(
      width: panelWidth,
      height: panelHeight,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  agora.primaryRemoteView(),

                  if (!agora.remoteHasVideo)
                    Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  colors: [
                                    Colors.red.shade400.withOpacity(0.4),
                                    Colors.orange.shade300.withOpacity(0.2),
                                  ],
                                ).createShader(bounds);
                              },
                              child: const Icon(
                                Icons.videocam_off,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_rounded,
                    color: Colors.orangeAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${guestName.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dynamic mic state indicator - UPDATED
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: AnimatedBuilder(
                animation: agora, // Listen to agora changes
                builder: (context, _) {
                  final hasGuest = agora.primaryRemoteUid.value != null;
                  bool guestHasAudio = false;

                  if (hasGuest) {
                    final guestUid = agora.primaryRemoteUid.value!;
                    final guestState = agora.remoteUsers.value[guestUid];
                    guestHasAudio = guestState?.hasAudio ?? false;
                  }

                  return Icon(
                    guestHasAudio ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: guestHasAudio
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    size: 12,
                  );
                },
              ),
            ),
          ),

          // Add drag handle at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                color: Colors.black.withOpacity(0.3),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: agora.remoteHasVideo
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            agora.remoteHasVideo ? 'Live' : 'Connecting...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== Visual helpers =====
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
      child: ClipRect(
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? Colors.black.withOpacity(0)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// ===== Chat List (stable wrapping) =====
class _ChatList extends StatefulWidget {
  final List messages;
  const _ChatList({required this.messages, super.key});
  @override
  State<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<_ChatList> {
  final _ctrl = ScrollController();

  @override
  void didUpdateWidget(covariant _ChatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ctrl.hasClients) {
          _ctrl.animateTo(
            _ctrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64, maxHeight: 180),
      child: ListView.builder(
        controller: _ctrl,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: widget.messages.length,
        itemBuilder: (_, i) {
          final m = widget.messages[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.25,
                ),
                children: [
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: SizedBox(width: 0),
                  ),
                  TextSpan(
                    text: '${m.handle}  ',
                    style: const TextStyle(
                      color: Color(0xFF58B5FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: m.text),
                ],
              ),
              softWrap: true,
              textAlign: TextAlign.left,
            ),
          );
        },
      ),
    );
  }
}

/// ===== Bottom Actions =====
class _BottomActions extends StatelessWidget {
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onChatToggle;
  final VoidCallback onViewers;
  final VoidCallback onGifts;
  final VoidCallback onPremium;
  final VoidCallback onSettings;
  final AgoraService agora; // Add this parameter

  const _BottomActions({
    required this.isPaused,
    required this.onPause,
    required this.onChatToggle,
    required this.onViewers,
    required this.onGifts,
    required this.onPremium,
    required this.onSettings,
    required this.agora, // Add this
  });

  Widget _item(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isSettings = false,
    bool isActive = false,
    bool showBadge = false, // Add this parameter
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isSettings ? 44 : 48,
                height: isSettings ? 44 : 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFFF6A00).withOpacity(0.3)
                      : Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFFF6A00).withOpacity(0.6)
                        : Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Icon(
                  icon,
                  color: isActive ? const Color(0xFFFF6A00) : Colors.white,
                  size: isSettings ? 20 : 24,
                ),
              ),
              if (showBadge)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6A00),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6A00).withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFFF6A00) : Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveHostBloc, LiveHostState>(
      buildWhen: (previous, current) =>
          previous.chatVisible != current.chatVisible,
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _item(
                state.chatVisible
                    ? Icons.chat_bubble_rounded
                    : Icons.chat_bubble_outline_rounded,
                'Chat',
                onChatToggle,
                isActive: state.chatVisible,
              ),
              _item(Icons.card_giftcard_rounded, 'Gifts', onGifts),

              _item(Icons.visibility_rounded, 'Viewers', onViewers),
              InkWell(
                onTap: onPause,
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isPaused ? 'Resume' : 'Pause',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),

              _item(Icons.star_rounded, 'Premiums', onPremium),
              _item(
                Icons.settings_rounded,
                'Settings',
                onSettings,
                isSettings: true,
                showBadge: agora.beautyActive.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

// Add this new widget for settings menu items
class _SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SettingsMenuItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.orangeAccent : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.orangeAccent : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== Request Card =====
class _JoinRequestCard extends StatelessWidget {
  final LiveJoinRequest req;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _JoinRequestCard({
    required this.req,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      color: const Color(0xFF070B12).withOpacity(.92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    (req.avatarUrl.isNotEmpty &&
                        req.avatarUrl.startsWith('http'))
                    ? NetworkImage(req.avatarUrl)
                    : const AssetImage('assets/images/logo.png')
                          as ImageProvider,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2ECC71),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Ambassador',
                          style: TextStyle(
                            color: Color(0xFF7ED957),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'wants to join your livestream',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CTAButton(
                  label: 'Accept',
                  bg: const Color(0xFF2ECC71),
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CTAButton(
                  label: 'Decline',
                  bg: const Color(0xFFE53935),
                  onTap: onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  final String label;
  final Color bg;
  final VoidCallback onTap;
  const _CTAButton({
    required this.label,
    required this.bg,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

/// ===== Paused Overlay =====
class _PausedOverlay extends StatelessWidget {
  final VoidCallback onResume;
  const _PausedOverlay({required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pause_circle_filled_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 8),
            const Text(
              'Stream Paused',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.0),
              child: Text(
                'Viewers will be notified when you resume your stream.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onResume,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6A00),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6A00).withOpacity(.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Resume Stream',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final String hostName;
  final String hostBadge;
  final String timeText;
  final String viewersText;
  final String? avatarUrl;
  final VoidCallback onEnd;

  const _HeaderBar({
    required this.hostName,
    required this.hostBadge,
    required this.timeText,
    required this.viewersText,
    required this.onEnd,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final ImageProvider img =
        (avatarUrl != null && avatarUrl!.startsWith('http'))
        ? NetworkImage(avatarUrl!)
        : const AssetImage('assets/images/logo.png') as ImageProvider;

    return _Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CircleAvatar(radius: 14, backgroundImage: img),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hostName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              _Badge(text: hostBadge),
            ],
          ),
          const SizedBox(width: 10),

          const Padding(padding: EdgeInsets.only(top: 2), child: _LiveDot()),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              timeText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              final tracker = sl<LiveSessionTracker>();
              final numericId = tracker.current!.livestreamId;
              final restParam = '${tracker.current!.livestreamId}';

              _registerParticipantsForCurrentSession();

              Navigator.pushNamed(context, RouteNames.listViewers);
            },
            child: const Padding(
              padding: EdgeInsets.only(top: 2, left: 3, right: 2),
              child: Icon(
                Icons.remove_red_eye_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              viewersText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const Spacer(),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _showEndStreamConfirmation(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF3D00).withOpacity(0.8),
                    const Color(0xFFFF6A00).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF3D00).withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.power_settings_new_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'End',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _registerParticipantsForCurrentSession() {
    try {
      final tracker = GetIt.I<LiveSessionTracker>();
      final current = tracker.current;

      if (current == null) {
        debugPrint('⚠️ No live session found for participants registration');
        return;
      }

      final numericId = current.livestreamId;
      final restParam = current.livestreamId.toString();

      debugPrint('🔧 Registering participants for livestream ID: $numericId');

      // Check if we're already registered for this session
      if (GetIt.I.isRegistered<ParticipantsRepository>()) {
        try {
          final existingRepo = GetIt.I<ParticipantsRepository>();
          // Check if it's the same session
          if (existingRepo is ParticipantsRepositoryImpl) {
            if (existingRepo.livestreamIdNumeric == numericId) {
              debugPrint('✅ Participants already registered for this session');
              return;
            }
          }

          // Different session - clean up
          GetIt.I<ParticipantsRepository>().dispose();
        } catch (_) {}
        GetIt.I.unregister<ParticipantsRepository>();
      }

      // Register new repository with current session
      GetIt.I.registerLazySingleton<ParticipantsRepository>(
        () => ParticipantsRepositoryImpl(
          GetIt.I<DioClient>(),
          GetIt.I<PusherService>(),
          livestreamIdNumeric: numericId,
          livestreamParam: restParam,
        ),
      );

      // Update ParticipantsBloc
      if (GetIt.I.isRegistered<ParticipantsBloc>()) {
        GetIt.I.unregister<ParticipantsBloc>();
      }

      GetIt.I.registerFactory<ParticipantsBloc>(
        () => ParticipantsBloc(GetIt.I<ParticipantsRepository>()),
      );

      debugPrint('✅ Registered participants for livestream ID: $numericId');
    } catch (e, stack) {
      debugPrint('❌ Failed to register participants: $e\n$stack');
    }
  }

  void _showEndStreamConfirmation(BuildContext context) {
    // Get the current state before showing dialog
    final liveHostBloc = context.read<LiveHostBloc>();
    final state = liveHostBloc.state;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return EndStreamConfirmationDialog(
          onConfirm: onEnd,
          onCancel: () {
            Navigator.of(context).pop();
          },
          viewerCount: state.viewers,
          elapsedSeconds: state.elapsedSeconds,
          messageCount: state.messages.length,
        );
      },
    );
  }
}

/// Modern TikTok-style Host Chat Widget with Emoji Picker
/// Ultra-modern TikTok-style Host Chat Widget
class _HostChatWidget extends StatefulWidget {
  final List<LiveChatMessage> messages;
  final Function(String) onSendMessage;

  const _HostChatWidget({required this.messages, required this.onSendMessage});

  @override
  State<_HostChatWidget> createState() => _HostChatWidgetState();
}

class _HostChatWidgetState extends State<_HostChatWidget>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _showEmojiPicker = false;
  bool _isScrolling = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scrollController.addListener(_handleScroll);

    // Auto-scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  void _handleScroll() {
    final offset = _scrollController.offset;
    setState(() {
      _scrollOffset = offset;
      _isScrolling = offset > 0;
    });
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _textController.clear();
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = false);

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });

    if (_showEmojiPicker) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _insertEmoji(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _textController.text = newText;
    _textController.selection = selection.copyWith(
      baseOffset: selection.start + emoji.length,
      extentOffset: selection.start + emoji.length,
    );

    _focusNode.requestFocus();
  }

  @override
  void didUpdateWidget(covariant _HostChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-scroll when new messages arrive
    if (widget.messages.length > oldWidget.messages.length) {
      _scrollToBottom();

      // Pulse animation for new message
      _fadeController.reset();
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Modern Chat Container with Depth Effect
        Container(
          height: 300,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            // borderRadius: const BorderRadius.vertical(
            //   top: Radius.circular(20),
            //   bottom: Radius.circular(8),
            // ),
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withOpacity(0.4),
            //     blurRadius: 30,
            //     spreadRadius: -10,
            //     offset: const Offset(0, 10),
            //   ),
            // ],
          ),
          child: ClipRRect(
            // borderRadius: const BorderRadius.vertical(
            //   top: Radius.circular(20),
            //   bottom: Radius.circular(8),
            // ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0),
                    Colors.white.withOpacity(0),
                  ],
                ),
                // borderRadius: const BorderRadius.vertical(
                //   top: Radius.circular(20),
                //   bottom: Radius.circular(8),
                // ),
                // border: Border.all(
                //   color: Colors.white.withOpacity(0.08),
                //   width: 1,
                // ),
              ),
              child: Stack(
                children: [
                  // Chat Messages List
                  Positioned.fill(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollEndNotification) {
                          setState(() => _isScrolling = false);
                        }
                        return false;
                      },
                      child: ListView.separated(
                        controller: _scrollController,
                        reverse: false,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: widget.messages.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final m = widget.messages[i];
                          final isNew = i == widget.messages.length - 1;
                          // final isHost = m.handle.toLowerCase().contains(
                          //   'host',
                          // );

                          final isHost = m.role == 'host';

                          return AnimatedBuilder(
                            animation: _fadeController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: isNew ? 0.9 : 1.0,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    isNew ? (1 - _fadeController.value) * 1 : 0,
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: _UltraModernChatBubble(
                              username: m.handle,
                              text: m.text,
                              avatarUrl: m.avatarUrl,
                              isHost: isHost,
                              index: i,
                              total: widget.messages.length,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Top Fade Gradient
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom Fade Gradient
                  // Positioned(
                  //   bottom: 0,
                  //   left: 0,
                  //   right: 0,
                  //   height: 40,
                  //   child: Container(
                  //     decoration: BoxDecoration(
                  //       gradient: LinearGradient(
                  //         begin: Alignment.bottomCenter,
                  //         end: Alignment.topCenter,
                  //         colors: [
                  //           Colors.black.withOpacity(0.3),
                  //           Colors.transparent,
                  //         ],
                  //       ),
                  //     ),
                  //   ),
                  // ),

                  // Scroll Indicator (appears when scrolled up)
                  // if (_isScrolling)
                  //   Positioned(
                  //     top: 12,
                  //     left: 0,
                  //     right: 0,
                  //     child: Center(
                  //       child: Container(
                  //         width: 40,
                  //         height: 4,
                  //         decoration: BoxDecoration(
                  //           color: Colors.white.withOpacity(0.3),
                  //           borderRadius: BorderRadius.circular(2),
                  //         ),
                  //       ),
                  //     ),
                  //   ),

                  // New Message Indicator
                  // if (widget.messages.isNotEmpty)
                  //   Positioned(
                  //     bottom: 12,
                  //     right: 12,
                  //     child: GestureDetector(
                  //       onTap: _scrollToBottom,
                  //       child: AnimatedContainer(
                  //         duration: const Duration(milliseconds: 300),
                  //         padding: const EdgeInsets.symmetric(
                  //           horizontal: 12,
                  //           vertical: 8,
                  //         ),
                  //         decoration: BoxDecoration(
                  //           color: const Color(0xFFFF6A00).withOpacity(0.9),
                  //           borderRadius: BorderRadius.circular(20),
                  //           boxShadow: [
                  //             BoxShadow(
                  //               color: const Color(
                  //                 0xFFFF6A00,
                  //               ).withOpacity(0.3),
                  //               blurRadius: 10,
                  //               spreadRadius: 2,
                  //             ),
                  //           ],
                  //         ),
                  //         child: Row(
                  //           mainAxisSize: MainAxisSize.min,
                  //           children: [
                  //             const Icon(
                  //               Icons.arrow_downward_rounded,
                  //               color: Colors.white,
                  //               size: 14,
                  //             ),
                  //             const SizedBox(width: 4),
                  //             Text(
                  //               '${widget.messages.length}',
                  //               style: const TextStyle(
                  //                 color: Colors.white,
                  //                 fontSize: 12,
                  //                 fontWeight: FontWeight.w700,
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Modern Input Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (_showEmojiPicker) ...[
                _ModernEmojiPicker(onEmojiSelected: _insertEmoji),
                const SizedBox(height: 8),
              ],

              Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: -5,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Emoji Button
                    GestureDetector(
                      onTap: _toggleEmojiPicker,
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _showEmojiPicker
                              ? const Color(0xFFFF6A00).withOpacity(0.2)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          _showEmojiPicker
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          color: _showEmojiPicker
                              ? const Color(0xFFFF6A00)
                              : Colors.white.withOpacity(0.7),
                          size: 20,
                        ),
                      ),
                    ),

                    // Text Field
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
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
                          onTap: () {
                            if (_showEmojiPicker) {
                              setState(() => _showEmojiPicker = false);
                            }
                          },
                          maxLines: 1,
                        ),
                      ),
                    ),

                    // Send Button
                    GestureDetector(
                      onTap: _sendMessage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _textController.text.trim().isEmpty
                                ? [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ]
                                : [
                                    const Color(0xFFFF6A00),
                                    const Color(0xFFFF3D00),
                                  ],
                          ),
                          boxShadow: _textController.text.trim().isEmpty
                              ? []
                              : [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF6A00,
                                    ).withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: _textController.text.trim().isEmpty
                              ? Colors.white.withOpacity(0.5)
                              : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ultra-modern chat bubble with iOS/TikTok design
class _UltraModernChatBubble extends StatelessWidget {
  final String username;
  final String text;
  final String? avatarUrl;
  final bool isHost;
  final int index;
  final int total;
  final String? role; // 'host', 'guest', 'moderator', 'viewer'

  const _UltraModernChatBubble({
    required this.username,
    required this.text,
    this.avatarUrl,
    this.isHost = false,
    this.role,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLatest = index == total - 1;
    final double opacity = 1.0 - (index / total) * 0.2;
    final Color bubbleColor = _getBubbleColor(isHost, role);
    final Color textColor = _getTextColor(isHost, role);
    final Color badgeColor = _getBadgeColor(role);
    final String displayName = _getDisplayName(username, role);

    return Padding(
      padding: EdgeInsets.only(
        top: index == 0 ? 8 : 4,
        bottom: isLatest ? 8 : 4,
      ),
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(0.005),
        alignment: FractionalOffset.center,
        child: Container(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar Section - ALL avatars on left side
              Transform.translate(
                offset: const Offset(0, -2),
                child: _buildAvatar(
                  avatarUrl,
                  username,
                  opacity,
                  role,
                  isLatest,
                ),
              ),

              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Username Row with Badge
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Badge based on role
                            if (role != null && role != 'viewer')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: badgeColor.withOpacity(0),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  role!.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    height: 1,
                                  ),
                                ),
                              ),

                            // Username
                            Flexible(
                              child: Text(
                                isHost ? '${displayName} 🎤' : displayName,
                                style: TextStyle(
                                  color: isHost
                                      ? AppColors.textRed
                                      : _getUsernameColor(
                                          role,
                                        ).withOpacity(opacity),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  height: 1,
                                  shadows: [
                                    if (isLatest)
                                      Shadow(
                                        color: Colors.black.withOpacity(0),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Chat Bubble
                      Container(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Stack(
                          children: [
                            // Background with gradient
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 5,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: TextStyle(
                                        color: textColor.withOpacity(opacity),
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.25,
                                        letterSpacing: -0.1,
                                        shadows: [
                                          if (isLatest)
                                            Shadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                        ],
                                      ),
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Host Badge - Moved to extreme top-right
                            // if (isHost)
                            //   Positioned(
                            //     top: 0,
                            //     right: 0,
                            //     child: Container(
                            //       padding: const EdgeInsets.symmetric(
                            //         horizontal: 8,
                            //         vertical: 4,
                            //       ),
                            //       decoration: BoxDecoration(
                            //         gradient: LinearGradient(
                            //           colors: [
                            //             Color(0xFFFF6A00).withOpacity(0.6),
                            //             Color(0xFFFF3D00).withOpacity(0.6),
                            //           ],
                            //         ),
                            //         borderRadius: BorderRadius.circular(12),
                            //         boxShadow: [
                            //           BoxShadow(
                            //             color: const Color(
                            //               0xFFFF6A00,
                            //             ).withOpacity(0.6),
                            //             blurRadius: 8,
                            //             spreadRadius: 1,
                            //           ),
                            //           BoxShadow(
                            //             color: Colors.black.withOpacity(0.2),
                            //             blurRadius: 4,
                            //             offset: const Offset(0, 2),
                            //           ),
                            //         ],
                            //       ),
                            //       child: Row(
                            //         mainAxisSize: MainAxisSize.min,
                            //         children: [
                            //           Icon(
                            //             Icons.verified_rounded,
                            //             color: Colors.white,
                            //             size: 12,
                            //           ),
                            //           const SizedBox(width: 4),
                            //           const Text(
                            //             'HOST',
                            //             style: TextStyle(
                            //               color: Colors.white,
                            //               fontSize: 9,
                            //               fontWeight: FontWeight.w900,
                            //               letterSpacing: 0.8,
                            //               height: 1,
                            //             ),
                            //           ),
                            //         ],
                            //       ),
                            //     ),
                            //   ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    String? avatarUrl,
    String username,
    double opacity,
    String? role,
    bool isLatest,
  ) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _getAvatarBorderColor(role).withOpacity(opacity * 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(opacity * 0.2),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _getAvatarGlowColor(role).withOpacity(opacity * 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Stack(
          children: [
            // Avatar image
            if (avatarUrl != null && avatarUrl.isNotEmpty)
              Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatar(username, role);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildDefaultAvatar(username, role);
                },
              )
            else
              _buildDefaultAvatar(username, role),

            // Online status indicator
            if (isLatest)
              Positioned(
                bottom: 0,
                right: 0,
                child: _PulsingDot(color: const Color(0xFFFF6A00), size: 4),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String username, String? role) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getAvatarGradientColors(role),
        ),
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for colors based on role
  Color _getBubbleColor(bool isHost, String? role) {
    if (isHost) return const Color(0xFFFF6A00);

    switch (role) {
      case 'moderator':
        return const Color(0xFF7B1FA2);
      case 'guest':
        return const Color(0xFF2196F3);
      case 'cohost':
        return const Color(0xFF4CAF50);
      default: // viewer
        return const Color(0xFF424242);
    }
  }

  Color _getTextColor(bool isHost, String? role) {
    if (isHost) return Colors.white;

    switch (role) {
      case 'moderator':
      case 'guest':
      case 'cohost':
        return Colors.white;
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  Color _getBadgeColor(String? role) {
    switch (role) {
      case 'moderator':
        return const Color(0xFF9C27B0);
      case 'guest':
        return const Color(0xFF2196F3);
      case 'cohost':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF757575);
    }
  }

  Color _getUsernameColor(String? role) {
    switch (role) {
      case 'moderator':
        return const Color(0xFFE1BEE7);
      case 'guest':
        return const Color(0xFF90CAF9);
      case 'cohost':
        return const Color(0xFFA5D6A7);
      case 'host':
        return const Color.fromARGB(255, 235, 39, 0);
      default:
        return const Color.fromARGB(255, 19, 100, 239);
    }
  }

  Color _getAvatarBorderColor(String? role) {
    if (role == 'host') return const Color(0xFFFF6A00);
    if (role == 'moderator') return const Color(0xFF9C27B0);
    if (role == 'guest') return const Color(0xFF2196F3);
    if (role == 'cohost') return const Color(0xFF4CAF50);
    return const Color(0xFF757575);
  }

  Color _getAvatarGlowColor(String? role) {
    if (role == 'host') return const Color(0xFFFF6A00);
    if (role == 'moderator') return const Color(0xFF9C27B0);
    if (role == 'guest') return const Color(0xFF2196F3);
    if (role == 'cohost') return const Color(0xFF4CAF50);
    return const Color(0xFF757575);
  }

  List<Color> _getAvatarGradientColors(String? role) {
    switch (role) {
      case 'host':
        return [const Color(0xFFFF6A00), const Color(0xFFFF3D00)];
      case 'moderator':
        return [const Color(0xFF7B1FA2), const Color(0xFF6A1B9A)];
      case 'guest':
        return [const Color(0xFF2196F3), const Color(0xFF1976D2)];
      case 'cohost':
        return [const Color(0xFF4CAF50), const Color(0xFF388E3C)];
      default:
        return [const Color(0xFF616161), const Color(0xFF424242)];
    }
  }

  String _getDisplayName(String username, String? role) {
    final cleanName = username.startsWith('@')
        ? username.substring(1)
        : username;

    switch (role) {
      case 'host':
        return '👑 $cleanName';
      case 'moderator':
        return '🛡️ $cleanName';
      case 'guest':
        return '🎤 $cleanName';
      case 'cohost':
        return '🌟 $cleanName';
      default:
        return cleanName;
    }
  }
}

// Pulsing dot animation for new messages
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({required this.color, required this.size});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 2,
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

/// Modern Emoji Picker
class _ModernEmojiPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;

  final List<String> _emojis = [
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
    '🤩',
    '😇',
    '🥳',
    '😜',
    '🤪',
    '🥺',
    '😤',
    '🤬',
    '🤯',
    '🥶',
    '😈',
    '👻',
    '💀',
    '🤡',
    '👽',
    '🦄',
    '🐶',
    '🐱',
    '🐼',
    '🦁',
    '🐯',
    '🦊',
    '🐰',
    '🐨',
    '🐵',
    '🦋',
  ];

  _ModernEmojiPicker({required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: _emojis.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => onEmojiSelected(_emojis[index]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.transparent,
              ),
              child: Center(
                child: Text(
                  _emojis[index],
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Modern chat bubble matching the live viewer style

// ===== Premium Bottom Sheet Widget =====
class _PremiumBottomSheet extends StatefulWidget {
  final ScrollController scrollController;
  final LiveSessionRepositoryImpl repo;
  final void Function(PremiumPackageModel) onActivate;

  const _PremiumBottomSheet({
    required this.scrollController,
    required this.repo,
    required this.onActivate,
  });

  @override
  State<_PremiumBottomSheet> createState() => _PremiumBottomSheetState();
}

class _PremiumBottomSheetState extends State<_PremiumBottomSheet> {
  bool _loading = true;
  List<PremiumPackageModel> _packages = [];
  WalletModel? _wallet;
  PremiumPackageModel? _selected;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      setState(() => _loading = true);
      final pkgs = await widget.repo.fetchCoinPackages();
      final w = await widget.repo.fetchWallet();
      setState(() {
        _packages = pkgs;
        _wallet = w;
        _selected = pkgs.isNotEmpty ? pkgs.first : null;
      });
    } catch (e) {
      debugPrint('❌ failed to fetch premium data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0E14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _loading
          ? SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFF6A00),
                  ),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Go Premium — select a coin package',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_wallet != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_wallet!.balance} coins',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${(_wallet!.usdEquivalentCents * 0.005).toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: widget.scrollController,
                    itemCount: _packages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = _packages[i];
                      final selected = p == _selected;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = p),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withOpacity(0.06)
                                : Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFFF6A00)
                                  : Colors.white12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${p.coins} coins',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${(p.priceUsdCents * 0.005).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (selected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6A00),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Selected',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selected == null
                            ? null
                            : () {
                                widget.onActivate(_selected!);
                              },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6A00),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _selected == null
                                  ? 'Select a package'
                                  : 'Activate with ${_selected!.title}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// ===== Cancel Premium Sheet Widget =====
class _CancelPremiumSheet extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onConfirm;

  const _CancelPremiumSheet({
    required this.scrollController,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0E14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ListView(
        controller: scrollController,
        shrinkWrap: true,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cancel Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cancelling premium will remove the premium badge and revert your stream to regular status. '
            'Viewers will be notified. You can re-activate premium anytime.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Keep Premium',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6A00),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancel Premium',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Add this new StatefulWidget class at the end of the file (before the last closing bracket)
class _DraggableGuestVideoPanel extends StatefulWidget {
  final double width;
  final double height;
  final Widget child;

  const _DraggableGuestVideoPanel({
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  _DraggableGuestVideoPanelState createState() =>
      _DraggableGuestVideoPanelState();
}

class _DraggableGuestVideoPanelState extends State<_DraggableGuestVideoPanel> {
  late Offset _position;
  late Size _screenSize;
  late double _panelWidth;
  late double _panelHeight;

  @override
  void initState() {
    super.initState();
    _panelWidth = widget.width;
    _panelHeight = widget.height;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenSize = MediaQuery.of(context).size;
      // Start position: right 16, bottom 100
      _position = Offset(
        _screenSize.width - _panelWidth - 16,
        _screenSize.height -
            _panelHeight -
            100 -
            MediaQuery.of(context).padding.bottom,
      );

      // Ensure position is within bounds
      _position = _clampPosition(_position);

      if (mounted) {
        setState(() {});
      }
    });
  }

  Offset _clampPosition(Offset position) {
    double x = position.dx;
    double y = position.dy;

    // Keep panel within screen bounds with some padding
    final double padding = 8;

    // Clamp X position
    x = x.clamp(padding, _screenSize.width - _panelWidth - padding);

    // Clamp Y position (account for top bar and bottom actions)
    final double topPadding = MediaQuery.of(context).padding.top + 100;
    final double bottomPadding = 180 + MediaQuery.of(context).padding.bottom;

    y = y.clamp(topPadding, _screenSize.height - _panelHeight - bottomPadding);

    return Offset(x, y);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
      _position = _clampPosition(_position);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Optional: Add snap-to-edge behavior
    final double screenCenterX = _screenSize.width / 2;

    if (_position.dx < screenCenterX - _panelWidth / 2) {
      // Snap to left
      setState(() {
        _position = Offset(8, _position.dy);
      });
    } else {
      // Snap to right
      setState(() {
        _position = Offset(_screenSize.width - _panelWidth - 8, _position.dy);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If position hasn't been initialized yet, return widget in original position
    if (_position == null) {
      return Positioned(
        right: 16,
        bottom: 100,
        width: _panelWidth,
        height: _panelHeight,
        child: widget.child,
      );
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      width: _panelWidth,
      height: _panelHeight,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: widget.child,
        ),
      ),
    );
  }
}
