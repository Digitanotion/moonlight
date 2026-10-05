import 'dart:async';

import 'package:flutter/widgets.dart';

/// Which scrollable a scroll-to-top request is aimed at.
enum ScrollTarget { watch, discover }

/// Tiny broadcast bus: the bottom-nav Home icon and the Watch/Discover tab
/// re-taps publish here, and the two tab scrollables listen. Keeps the nav
/// widgets decoupled from the tab scroll controllers.
class ScrollToTopService {
  ScrollToTopService._();

  static final _ctrl = StreamController<ScrollTarget>.broadcast();

  static Stream<ScrollTarget> get stream => _ctrl.stream;

  static void request(ScrollTarget target) => _ctrl.add(target);

  /// Smoothly scrolls [c] to the top; no-op if it isn't attached yet.
  static void animateToTop(ScrollController c) {
    if (!c.hasClients || c.offset <= 0) return;
    c.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }
}
