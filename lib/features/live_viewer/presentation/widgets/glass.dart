import 'dart:ui';

import 'package:flutter/material.dart';

Widget glass({required Widget child, double radius = 16, Color? color}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 4),
      child: Container(
        decoration: BoxDecoration(
          color: (color ?? Colors.black.withOpacity(.30)),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(.08), width: 1),
        ),
        child: child,
      ),
    ),
  );
}
