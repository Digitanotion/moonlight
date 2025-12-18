// lib/features/live_viewer/presentation/pages/live_viewer_pager.dart
// Vertical pager that instantiates a ViewerRepositoryImpl per item and provides a ViewerBloc for each page.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
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

  const LiveViewerPager({
    super.key,
    required this.items,
    required this.initialIndex,
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
    // Create repository instances for each item. We'll dispose them on widget dispose.
    _repos = widget.items.map(_makeRepoForItem).toList();
  }

  @override
  void dispose() {
    for (final r in _repos) {
      try {
        r.dispose();
      } catch (_) {}
    }
    _controller.dispose();
    super.dispose();
  }

  ViewerRepositoryImpl _makeRepoForItem(LiveItem item) {
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
    // PageView is vertical, each page wraps your existing LiveViewerScreen with ViewerBloc.
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.items.length,
        itemBuilder: (context, i) {
          final repo = _repos[i];
          // NOTE: ViewerBloc constructor takes a positional parameter (ViewerBloc(this.repo))
          // so we must pass repo positionally, not as a named parameter.
          return BlocProvider<ViewerBloc>(
            create: (_) => ViewerBloc(repo),
            child: LiveViewerScreen(repository: repo),
          );
        },
        onPageChanged: (idx) {
          // optional: you may want to do analytics or prefetch here
        },
      ),
    );
  }
}
