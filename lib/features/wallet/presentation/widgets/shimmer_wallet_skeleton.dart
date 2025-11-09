import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart' show Shimmer;

class WalletShimmer extends StatelessWidget {
  const WalletShimmer({Key? key}) : super(key: key);

  Widget _box(double h, {double radius = 8}) {
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade300;
    final highlight = Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _box(80),
            SizedBox(height: 16),
            _box(60),
            SizedBox(height: 16),
            _box(200),
          ],
        ),
      ),
    );
  }
}
