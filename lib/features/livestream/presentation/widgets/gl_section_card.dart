import 'package:flutter/material.dart';

class GLSectionCard extends StatelessWidget {
  const GLSectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2240).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
