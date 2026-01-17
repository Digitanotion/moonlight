// lib/features/live_viewer/presentation/pages/live_viewer_pager.dart
// Vertical pager that instantiates a ViewerRepositoryImpl per item and provides a ViewerBloc for each page.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_screen.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import '../../domain/entities.dart' show HostInfo;

class LiveViewerPager extends StatefulWidget {
  final List<LiveItem> items;
  final int initialIndex;
  final List<Map<String, dynamic>>? allArgs; // Add this

  const LiveViewerPager({
    super.key,
    required this.items,
    required this.initialIndex,
    this.allArgs, // Add this
  });

  @override
  State<LiveViewerPager> createState() => _LiveViewerPagerState();
}

class _LiveViewerPagerState extends State<LiveViewerPager> {
  late final PageController _controller;
  late final List<ViewerRepositoryImpl> _repos;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
    _repos = widget.items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return _makeRepoForItem(item, index);
    }).toList();
  }

  ViewerRepositoryImpl _makeRepoForItem(LiveItem item, int index) {
    final dio = sl<DioClient>();
    final pusher = sl<PusherService>();
    final authLocal = sl<AuthLocalDataSource>();

    DateTime? parsedStartedAt;
    final sa = item.startedAt.toString();
    parsedStartedAt = DateTime.tryParse(sa);

    final host = HostInfo(
      name: item.role ?? 'Host',
      title: item.title ?? '',
      subtitle: '',
      badge: item.role ?? 'Superstar',
      avatarUrl: item.coverUrl ?? '',
      isFollowed: item.isFollowed ?? false,
    );

    return ViewerRepositoryImpl(
      http: dio,
      pusher: pusher,
      authLocalDataSource: authLocal,
      agoraViewerService: sl<AgoraViewerService>(),
      livestreamParam: item.uuid ?? item.id.toString(),
      livestreamIdNumeric: item.id,
      channelName: item.channel ?? '',
      hostUserUuid: item.hostUuid,
      initialHost: host,
      startedAt: parsedStartedAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.items.length,
        itemBuilder: (context, i) {
          final repo = _repos[i];
          // Get the routeArgs for this specific item
          final routeArgs = widget.allArgs != null && widget.allArgs!.length > i
              ? widget.allArgs![i]
              : {
                  // Fallback if allArgs not provided
                  'id': widget.items[i].id,
                  'uuid': widget.items[i].uuid,
                  'channel': widget.items[i].channel ?? '',
                  'isPremium': widget.items[i].isPremium ?? 0,
                  'premiumFee': widget.items[i].premiumFee ?? 0,
                };

          return BlocProvider<ViewerBloc>(
            create: (_) => ViewerBloc(repo),
            child: LiveViewerScreen(
              repository: repo,
              routeArgs: routeArgs, // Pass routeArgs here!
            ),
          );
        },
      ),
    );
  }
}
