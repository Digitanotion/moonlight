// Create a new file: lib/features/live_viewer/presentation/pages/live_viewer_from_notification.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_screen.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/network_monitor_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/reconnection_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/role_change_service.dart';

class LiveViewerFromNotification extends StatelessWidget {
  final Map<String, dynamic> args;

  const LiveViewerFromNotification({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    // Extract values from args
    final id = args['id'] as int? ?? 0;
    final uuid = args['uuid'] as String? ?? '';
    final channel = args['channel'] as String? ?? '';
    final hostUuid = args['hostUuid'] as String?;
    final hostName = args['hostName'] as String? ?? 'Host';
    final hostAvatar = args['hostAvatar'] as String? ?? '';
    final title = args['title'] as String? ?? 'Live Stream';
    final role = args['role'] as String? ?? 'viewer';

    debugPrint('=== NOTIFICATION VIEWER ===');
    debugPrint('Creating viewer from notification: id=$id, channel=$channel');

    // Create the repository
    final repository = ViewerRepositoryImpl(
      http: GetIt.I<DioClient>(),
      pusher: GetIt.I<PusherService>(),
      authLocalDataSource: GetIt.I<AuthLocalDataSource>(),
      agoraViewerService: GetIt.I<AgoraViewerService>(),
      livestreamParam: uuid,
      livestreamIdNumeric: id,
      channelName: channel,
      hostUserUuid: hostUuid,
      initialHost: HostInfo(
        name: hostName,
        title: title,
        subtitle: '',
        badge: role,
        avatarUrl: hostAvatar.isNotEmpty
            ? hostAvatar
            : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(hostName)}',
      ),
      startedAt: DateTime.tryParse(args['startedAt'] as String? ?? ''),
    );

    // Create the bloc
    final viewerBloc = ViewerBloc(
      repository,
      liveStreamService: GetIt.I<LiveStreamService>(),
      agoraViewerService: GetIt.I<AgoraViewerService>(),
      networkMonitorService: GetIt.I<NetworkMonitorService>(),
      reconnectionService: GetIt.I<ReconnectionService>(),
      roleChangeService: GetIt.I<RoleChangeService>(),
    );

    // Initialize the bloc with args
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewerBloc.add(ViewerStarted());
    });

    // Return the screen wrapped with BlocProvider
    return BlocProvider<ViewerBloc>.value(
      value: viewerBloc,
      child: LiveViewerScreen(repository: repository, routeArgs: args),
    );
  }
}
