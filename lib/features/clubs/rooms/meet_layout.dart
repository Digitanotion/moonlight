// lib/features/clubs/rooms/meet_layout.dart
//
// Club video room tiling: a "featured" stage like multi-guest live rooms.
//
//  • 1 person  → fills the stage.
//  • 2         → two tall tiles side by side.
//  • 3         → host full-width on top, two below.
//  • 4+        → host + first guest as two big tiles on top, everyone else
//                in smaller rows underneath (2, 3 or 4 per row, chosen so
//                rows stay even — e.g. 10 = 2 big + 4 + 4). Narrow phones
//                cap rows at 3 so small tiles never get too thin.
//
// A short row is centred, and the whole block is scaled to fit and centred
// on the stage, so it looks right on any phone or tablet. Tiles stay close
// to square, so nobody becomes a tall sliver.

import 'dart:math' as math;
import 'dart:ui';

class StageLayout {
  /// One rect per person, in order (host first).
  final List<Rect> tiles;

  /// How many of the first tiles are the big "featured" ones.
  final int featuredCount;

  const StageLayout(this.tiles, this.featuredCount);
}

/// Row sizes, top to bottom, for [n] people. [maxPerRow] caps the small
/// rows (3 on narrow phones, 4 on normal phones — see [maxPerRowFor]).
List<int> stageRows(int n, {int maxPerRow = 4}) {
  if (n <= 0) return const [];
  if (n == 1) return const [1];
  if (n == 2) return const [2];
  if (n == 3) return const [1, 2];
  final rest = n - 2;
  final per = math.min(maxPerRow, switch (rest) {
    <= 2 => 2,
    3 => 3,
    4 => 2,
    <= 6 => 3,
    _ => 4,
  });
  final rows = <int>[2];
  var left = rest;
  while (left > 0) {
    // Balance the last two rows (5 → 3+2, 7 → 4+3) rather than 4+1.
    final take = left > per && left < per * 2
        ? (left / 2).ceil()
        : math.min(per, left);
    rows.add(take);
    left -= take;
  }
  return rows;
}

/// Small tiles never get narrower than this — on a narrow phone that
/// means 3 per row instead of 4.
const minSmallTileWidth = 84.0;

int maxPerRowFor(double width, {double gap = 4}) =>
    ((width + gap) / (minSmallTileWidth + gap)).floor().clamp(2, 4);

const _tallTiles = 4 / 3; // 2 people side by side
const _wideHost = 0.75; // 3 people: host across the top
const _smallTiles = 0.9;

StageLayout stageLayout(int n, Size box, {double gap = 4}) {
  if (n <= 0 || box.isEmpty) return const StageLayout([], 0);
  if (n == 1) return StageLayout([Offset.zero & box], 1);

  final rows = stageRows(n, maxPerRow: maxPerRowFor(box.width, gap: gap));
  double widthFor(int perRow) => (box.width - gap * (perRow - 1)) / perRow;

  // Featured (first) row cell, and one shared cell size for all the small
  // rows so their tiles line up in a grid. Height / width per row:
  final featuredAspect = rows.length == 1
      ? _tallTiles // 2 people
      : rows[0] == 1
      ? _wideHost // 3 people
      : 1.0;
  final bigW = widthFor(rows[0]);
  final smallPer = rows.length > 1 ? rows.skip(1).reduce(math.max) : 1;
  final smallW = widthFor(smallPer);
  final widths = [bigW, for (var r = 1; r < rows.length; r++) smallW];
  final heights = [
    bigW * featuredAspect,
    for (var r = 1; r < rows.length; r++) smallW * _smallTiles,
  ];

  // Too tall for the stage → shrink the tiles (not the gaps) to fit.
  final gaps = gap * (rows.length - 1);
  final contentH = heights.fold<double>(0, (a, b) => a + b);
  final scale = contentH + gaps > box.height
      ? (box.height - gaps) / contentH
      : 1.0;
  var y = (box.height - (contentH * scale + gaps)) / 2;

  final rects = <Rect>[];
  for (var r = 0; r < rows.length; r++) {
    final w = widths[r] * scale;
    final h = heights[r] * scale;
    final rowW = rows[r] * w + (rows[r] - 1) * gap;
    var x = (box.width - rowW) / 2;
    for (var i = 0; i < rows[r]; i++) {
      rects.add(Rect.fromLTWH(x, y, w, h));
      x += w + gap;
    }
    y += h + gap;
  }
  return StageLayout(rects, rows[0]);
}
