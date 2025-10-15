import 'package:flutter/material.dart';

class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;
  final double? widthFactor;
  const SkeletonLine({this.width, this.height = 10, this.widthFactor});

  @override
  Widget build(BuildContext context) {
    final w = width ?? MediaQuery.of(context).size.width * (widthFactor ?? 1);
    return Container(
      width: w,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class SkeletonPill extends StatelessWidget {
  final double width;
  final double height;
  const SkeletonPill({required this.width, this.height = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
