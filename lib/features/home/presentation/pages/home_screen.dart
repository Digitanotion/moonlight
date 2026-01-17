import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/core/services/service_registration_manager.dart';
import 'package:moonlight/core/services/unread_badge_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_bloc.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/section_header.dart';
import '../widgets/live_now_section.dart';
import '../widgets/bottom_nav.dart';
import '../../../../core/injection_container.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ServiceRegistrationManager _serviceManager =
      ServiceRegistrationManager();
  // StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  // bool _showReconnectBanner = false;
  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _showReconnectBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize connectivity listener
    _initConnectivityListener();

    // Initialize unread service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final unreadService = GetIt.instance<UnreadBadgeService>();
        unreadService.initialize();
      } catch (e) {
        debugPrint('Error initializing unread service: $e');
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, check connection
      _checkServiceConnection();
    }
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results is List<ConnectivityResult>) {
        final hasConnection = results.any(
          (result) => result != ConnectivityResult.none,
        );
        if (hasConnection) {
          _reconnectServices();
        }
      } else if (results is ConnectivityResult) {
        // For backward compatibility
        if (results != ConnectivityResult.none) {
          _reconnectServices();
        }
      }
    });
  }

  Future<void> _checkServiceConnection() async {
    try {
      final pusher = GetIt.instance<PusherService>();
      if (!pusher.isConnected && _serviceManager.isRegistered) {
        setState(() {
          _showReconnectBanner = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking service connection: $e');
    }
  }

  Future<void> _reconnectServices() async {
    if (!_serviceManager.isRegistered || _serviceManager.isRegistering) {
      return;
    }

    try {
      await _serviceManager.reconnect();

      if (mounted) {
        setState(() {
          _showReconnectBanner = false;
        });

        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reconnected to real-time features'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showReconnectBanner = true;
        });
      }
    }
  }

  Widget _buildReconnectBanner() {
    if (!_showReconnectBanner) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.withOpacity(0.9),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reconnecting to real-time features...',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: _reconnectServices,
            child: Text(
              'RETRY',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LiveFeedBloc>(),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.dark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Reconnection banner
                // _buildReconnectBanner(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HomeAppBar(),
                      const SizedBox(height: 8),

                      // Header row: SectionHeader + See Posts
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          children: [
                            const Expanded(
                              child: SectionHeader(
                                title: 'Live Now',
                                trailingFilter: true,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                RouteNames.postsPage,
                              ),
                              child: const Text(
                                'See Posts',
                                style: TextStyle(
                                  color: AppColors.primary_,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Vertical grid feed (pull-to-refresh inside)
                      const LiveNowSection(),
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
}
