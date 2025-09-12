// -----------------------------
// FILE: lib/features/live/ui/widgets/pause_overlay.dart
// -----------------------------
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/presentation/cubits/live_cubits.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveMetaCubit, LiveMetaState>(
      builder: (context, state) {
        if (!state.meta.isPaused) return const SizedBox.shrink();
        return Positioned.fill(
          child: Stack(
            children: [
              // Background image to match the paused screenshot
              // In PauseOverlay -> Positioned.fill Image.asset(...):
              Image.asset(
                'assets/images/onboard_2.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const SizedBox.shrink(), // don’t block UI if missing
              ),

              // Dim layer
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(.45)),
              ),

              // Frosted card with pause icon + message + leave button
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.35),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.pause_circle_filled,
                            color: Colors.white,
                            size: 26,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Stream Paused',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The host has temporarily paused this\nlivestream. Please stay tuned...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),
                    _LeaveButton(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaveButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white70),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      onPressed: () => Navigator.of(context).maybePop(),
      child: const Text('Leave Stream'),
    );
  }
}
