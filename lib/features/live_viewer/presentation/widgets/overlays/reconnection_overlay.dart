// lib/features/live_viewer/presentation/widgets/overlays/reconnection_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

class ReconnectionOverlay extends StatelessWidget {
  const ReconnectionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.showReconnectOverlay != n.showReconnectOverlay ||
          p.reconnectMessage != n.reconnectMessage ||
          p.reconnectAttempts != n.reconnectAttempts,
      builder: (context, state) {
        if (!state.showReconnectOverlay) return const SizedBox.shrink();

        return IgnorePointer(
          ignoring: false,
          child: Container(
            color: Colors.black.withOpacity(0.85),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    state.reconnectMessage ?? 'Reconnecting...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (state.reconnectAttempts > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Attempt ${state.reconnectAttempts}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  TextButton(
                    onPressed: () {
                      context.read<ViewerBloc>().add(
                        const ReconnectionOverlayDismissed(),
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Leave Stream',
                      style: TextStyle(color: Colors.white70),
                    ),
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
