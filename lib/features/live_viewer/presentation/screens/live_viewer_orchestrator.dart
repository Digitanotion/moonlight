// lib/features/live_viewer/presentation/screens/live_viewer_orchestrator.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/screens/guest_mode_screen.dart';
import 'package:moonlight/features/live_viewer/presentation/screens/viewer_mode_screen.dart';

/// Main coordinator that switches between viewer and guest modes
class LiveViewerOrchestrator extends StatelessWidget {
  final ViewerRepositoryImpl repository;

  const LiveViewerOrchestrator({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (previous, current) => previous.viewMode != current.viewMode,
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildScreenForMode(state.viewMode),
        );
      },
    );
  }

  Widget _buildScreenForMode(ViewMode mode) {
    return switch (mode) {
      ViewMode.viewer => ViewerModeScreen(
        key: const ValueKey('viewer_mode'),
        repository: repository,
      ),
      ViewMode.guest || ViewMode.cohost => GuestModeScreen(
        key: const ValueKey('guest_mode'),
        repository: repository,
      ),
    };
  }
}
