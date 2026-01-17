import 'package:flutter/material.dart';

class AnimatedTabStack extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const AnimatedTabStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(children.length, (i) {
        final bool isActive = i == index;

        return IgnorePointer(
          ignoring: !isActive,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: isActive ? 1 : 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: isActive ? Offset.zero : const Offset(0.04, 0),
              child: TickerMode(enabled: isActive, child: children[i]),
            ),
          ),
        );
      }),
    );
  }
}
