import 'package:flutter/material.dart';

class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        height: 78,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.08),
        ),
      ),
    );
  }
}
