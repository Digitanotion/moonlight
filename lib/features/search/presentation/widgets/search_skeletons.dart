import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:moonlight/core/theme/app_colors.dart';

Widget shimmerBox({double? w, double? h, BorderRadius? r}) {
  return Shimmer.fromColors(
    baseColor: AppColors.dark.withOpacity(.4),
    highlightColor: AppColors.dark.withOpacity(.2),
    child: Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: r ?? BorderRadius.circular(8),
      ),
    ),
  );
}
