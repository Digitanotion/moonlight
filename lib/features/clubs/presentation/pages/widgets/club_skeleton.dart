import 'package:flutter/material.dart';

class ClubSkeletonList extends StatelessWidget {
  const ClubSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(), // ✅ IMPORTANT
      shrinkWrap: true, // ✅ IMPORTANT
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(14),
          ),
        );
      },
    );
  }
}
