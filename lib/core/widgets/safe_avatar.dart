import 'package:flutter/material.dart';

class SafeAvatar extends StatelessWidget {
  final String? url;
  final double radius;

  const SafeAvatar({super.key, required this.url, this.radius = 20});

  bool get _valid =>
      url != null &&
      url!.isNotEmpty &&
      url != 'none' &&
      url!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white12,
      backgroundImage: _valid ? NetworkImage(url!) : null,
      child: !_valid ? const Icon(Icons.person, color: Colors.white70) : null,
    );
  }
}
