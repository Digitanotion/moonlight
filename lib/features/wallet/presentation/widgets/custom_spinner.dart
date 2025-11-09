import 'package:flutter/material.dart';

class CustomSpinner extends StatelessWidget {
  final double size;
  final Color? color;

  const CustomSpinner({Key? key, this.size = 36, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.secondary;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(c),
      ),
    );
  }
}
