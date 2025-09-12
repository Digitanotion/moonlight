// -----------------------------
// FILE: lib/features/live/ui/widgets/request_button.dart
// -----------------------------
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/presentation/cubits/live_cubits.dart';

class RequestToJoinButton extends StatelessWidget {
  const RequestToJoinButton({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6A00),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => context.read<BannerCubit>().requestToJoin(),
        icon: const Icon(Icons.send),
        label: const Text('Request to Join'),
      ),
    );
  }
}
