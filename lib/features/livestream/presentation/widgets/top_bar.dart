// -----------------------------
// FILE: lib/features/live/ui/widgets/top_bar.dart
// -----------------------------
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/domain/entities/live_entities.dart';
import 'package:moonlight/features/livestream/presentation/cubits/live_cubits.dart';

class LiveTopBar extends StatelessWidget {
  const LiveTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveMetaCubit, LiveMetaState>(
      builder: (context, state) {
        final meta = state.meta;
        final host = state.host;
        String mmss(Duration d) {
          final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
          final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
          return '$m:$s';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT: LIVE + timer
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    color: Colors.black.withOpacity(.35),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          mmss(meta.elapsed),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // CENTER: Topic + host card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _pill(text: meta.topic, widthFactor: 0.9),
                      const SizedBox(height: 6),
                      _hostRow(host),
                    ],
                  ),
                ),
              ),

              // RIGHT: viewers & close
              Row(
                children: [
                  _viewerPill(meta.viewers),
                  const SizedBox(width: 6),
                  _closeBtn(context),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill({required String text, double widthFactor = 1}) =>
      FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );

  Widget _hostRow(LiveHost host) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.35),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(host.avatarUrl),
              radius: 14,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  host.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Mental health Coach · 1.2M Fans',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _badge('Superstar'),
            const SizedBox(width: 8),
            _followBtn(),
          ],
        ),
      ],
    ),
  );

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B).withOpacity(.8),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFFFA64D),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _followBtn() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFF6A00),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'Follow',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );

  Widget _viewerPill(int viewers) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.35),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.remove_red_eye, color: Colors.white, size: 18),
        const SizedBox(width: 6),
        Text('$viewers', style: const TextStyle(color: Colors.white)),
      ],
    ),
  );

  Widget _closeBtn(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(context).maybePop(),
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.35),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.close, color: Colors.white),
    ),
  );
}
