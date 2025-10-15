import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class FeedSkeletonList extends StatelessWidget {
  const FeedSkeletonList({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => _CardSkeleton(),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1432),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const ListTile(
            leading: CircleAvatar(radius: 20),
            title: SizedBox(height: 16, width: 120),
            subtitle: SizedBox(height: 12, width: 180),
            trailing: Icon(Icons.more_horiz, color: Colors.white54),
          ),
          AspectRatio(aspectRatio: 1, child: Container(color: Colors.white10)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: const [
                _ChipBox(width: 60),
                SizedBox(width: 10),
                _ChipBox(width: 60),
                SizedBox(width: 10),
                _ChipBox(width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipBox extends StatelessWidget {
  const _ChipBox({required this.width});
  final double width;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
