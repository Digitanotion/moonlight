// lib/features/livestream/presentation/widgets/request_join_bar.dart
import 'package:flutter/material.dart';

class RequestJoinBar extends StatelessWidget {
  final VoidCallback onRequest;
  final bool pending;
  const RequestJoinBar({
    super.key,
    required this.onRequest,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: pending
            ? Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: const Text(
                  '…Pending approval',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A1A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onRequest,
                icon: const Icon(Icons.video_call_rounded),
                label: const Text('Request to Join'),
              ),
      ),
    );
  }
}
