// lib/features/live_viewer/presentation/pages/live_viewer_pager.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart'
    show HostInfo;
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_screen.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/network_monitor_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/reconnection_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/role_change_service.dart';

class LiveViewerPager extends StatefulWidget {
  final List<LiveItem> items;
  final int initialIndex;
  final List<Map<String, dynamic>>? allArgs;

  const LiveViewerPager({
    super.key,
    required this.items,
    required this.initialIndex,
    this.allArgs,
  });

  @override
  State<LiveViewerPager> createState() => _LiveViewerPagerState();
}

class _LiveViewerPagerState extends State<LiveViewerPager> {
  late final PageController _controller;
  late final List<ViewerRepositoryImpl> _repos;

  int _currentPage = 0;
  final Set<int> _prefetchedPages = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);

    _repos = widget.items.asMap().entries.map((e) {
      return _makeRepoForItem(e.value);
    }).toList();

    // keepAlive = true means dispose() on the repo only sends /leave
    // and resets wiring flags — it does NOT close stream controllers.
    // This allows the repo to be rewired on swipe-back.
    for (final repo in _repos) {
      repo.keepAlive = true;
    }

    _controller.addListener(_onPageScrolled);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAdjacentCovers(widget.initialIndex);
      _prefetchRtcForPage(widget.initialIndex);
      _prefetchRtcForPage(widget.initialIndex + 1);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onPageScrolled);
    _controller.dispose();
    // Hard dispose all repos when the pager exits
    for (final repo in _repos) {
      repo.keepAlive = false;
      try {
        repo.dispose();
      } catch (_) {}
    }
    super.dispose();
  }

  void _onPageScrolled() {
    if (!_controller.hasClients) return;
    final raw = _controller.page ?? widget.initialIndex.toDouble();
    final nearestPage = raw.round();
    if (nearestPage == _currentPage) return;

    final previousPage = _currentPage;
    _currentPage = nearestPage;

    _precacheAdjacentCovers(nearestPage);
    _prefetchRtcForPage(nearestPage);
    _prefetchRtcForPage(nearestPage + 1);

    // On swipe-back: repo was soft-disposed (keepAlive=true), so stream
    // controllers are still open. Call resetWiring() so ensureWiredOnce()
    // runs _wireInternal() again and re-joins Agora.
    if (nearestPage < previousPage &&
        nearestPage >= 0 &&
        nearestPage < _repos.length) {
      final repo = _repos[nearestPage];
      debugPrint(
        '🔄 [Pager] Swipe back to page $nearestPage — resetting wiring',
      );
      repo.resetWiring();
      _prefetchedPages.remove(nearestPage);
    }
  }

  void _precacheAdjacentCovers(int centre) {
    for (final i in [centre - 1, centre, centre + 1]) {
      if (i < 0 || i >= widget.items.length) continue;
      final url = widget.items[i].coverUrl;
      if (url != null && url.isNotEmpty && mounted) {
        precacheImage(NetworkImage(url), context).ignore();
      }
    }
  }

  void _prefetchRtcForPage(int index) {
    if (index < 0 || index >= _repos.length) return;
    if (_prefetchedPages.contains(index)) return;
    _prefetchedPages.add(index);
    _repos[index].prefetchRtcToken();
  }

  ViewerRepositoryImpl _makeRepoForItem(LiveItem item) {
    return ViewerRepositoryImpl(
      http: sl<DioClient>(),
      pusher: sl<PusherService>(),
      authLocalDataSource: sl<AuthLocalDataSource>(),
      agoraViewerService: sl<AgoraViewerService>(),
      livestreamParam: item.uuid,
      livestreamIdNumeric: item.id,
      channelName: item.channel,
      hostUserUuid: item.hostUuid,
      initialHost: HostInfo(
        name: item.role,
        title: item.title ?? '',
        subtitle: '',
        badge: item.role,
        avatarUrl: item.coverUrl ?? '',
        isFollowed: item.isFollowed ?? false,
      ),
      startedAt: item.startedAt != null
          ? DateTime.tryParse(item.startedAt!)
          : null,
    );
  }

  Map<String, dynamic> _routeArgsForIndex(int i) {
    if (widget.allArgs != null && widget.allArgs!.length > i) {
      return widget.allArgs![i];
    }
    final item = widget.items[i];
    return {
      'id': item.id,
      'uuid': item.uuid,
      'channel': item.channel,
      'hostUuid': item.hostUuid,
      'hostName': item.handle.replaceFirst('@', ''),
      'hostAvatar': item.coverUrl,
      'title': item.title,
      'startedAt': item.startedAt,
      'role': item.role,
      'isPremium': item.isPremium ?? 0,
      'premiumFee': item.premiumFee ?? 0,
      'livestreamId': item.uuid,
      'livestreamIdNumeric': item.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(),
        itemCount: widget.items.length,
        itemBuilder: (context, i) {
          final repo = _repos[i];
          final routeArgs = _routeArgsForIndex(i);
          return BlocProvider<ViewerBloc>(
            create: (_) => ViewerBloc(
              repo,
              agoraViewerService: sl<AgoraViewerService>(),
              liveStreamService: sl<LiveStreamService>(),
              networkMonitorService: sl<NetworkMonitorService>(),
              reconnectionService: sl<ReconnectionService>(),
              roleChangeService: sl<RoleChangeService>(),
            ),
            child: LiveViewerScreen(repository: repo, routeArgs: routeArgs),
          );
        },
      ),
    );
  }
}
