// lib/features/live_viewer/presentation/widgets/role_change_handler.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

/// Handles role change events and shows appropriate UI feedback
class RoleChangeHandler extends StatelessWidget {
  const RoleChangeHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ViewerBloc, ViewerState>(
      listenWhen: (previous, current) =>
          previous.currentRole != current.currentRole,
      listener: (context, state) {
        final role = state.currentRole;

        // Show toast message for role changes
        if (role == 'guest' || role == 'cohost') {
          _showGuestPromotionToast(context);
        } else if (role == 'audience' || role == 'viewer') {
          // Only show demotion toast if it's not the initial state
          if (state.currentRole != state.currentRole) {
            _showDemotionToast(context);
          }
        }
      },
      child: const SizedBox.shrink(),
    );
  }

  void _showGuestPromotionToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You\'re now a guest!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'You can participate in the stream',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[800],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showDemotionToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Back to audience',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'You are now viewing as audience',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[800],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
