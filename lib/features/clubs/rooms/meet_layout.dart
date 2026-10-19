// lib/features/clubs/rooms/meet_layout.dart
//
// Google Meet-style tiling for the club video room.
//
// For n cameras in a box, try every row/column split and keep the one with
// the biggest tiles whose shape stays close to a camera picture (videos are
// cropped to fill their tile, so a tile far taller or wider than the camera
// cuts people off). Result on an upright phone: 1 → full, 2 → stacked,
// 3–4 → 2×2, 5–6 → 2×3, 7–8 → 2×4, 9 → 3×3, 10 → 3×4; side by side on
// wide screens. A short last row is centred, like Meet.

import 'dart:math' as math;
import 'dart:ui';

class MeetGrid {
  final int columns;
  final int rows;
  final Size cell;

  /// Top-left of each tile, in order, relative to the box.
  final List<Offset> origins;

  const MeetGrid(this.columns, this.rows, this.cell, this.origins);
}

/// [targetAspect] is the tile width / height we aim for (slightly
/// portrait, like a phone camera). [gap] is the space between tiles.
MeetGrid meetGrid(
  int n,
  Size box, {
  double targetAspect = 0.85,
  double gap = 4,
}) {
  if (n <= 0 || box.isEmpty) return MeetGrid(0, 0, Size.zero, const []);

  var bestCols = 1;
  var bestScore = -1.0;
  for (var cols = 1; cols <= n; cols++) {
    final rows = (n / cols).ceil();
    if (cols * (rows - 1) >= n) continue; // would leave a whole row empty
    final w = (box.width - gap * (cols - 1)) / cols;
    final h = (box.height - gap * (rows - 1)) / rows;
    if (w <= 0 || h <= 0) continue;
    final ratio = w / h;
    // 1.0 when the tile is exactly the target shape, falling off fast as it
    // gets skinnier or flatter.
    final shapeFit = math.pow(
      math.min(ratio, targetAspect) / math.max(ratio, targetAspect),
      2,
    );
    final score = w * h * shapeFit;
    if (score > bestScore + 0.5) {
      bestScore = score;
      bestCols = cols;
    }
  }

  final cols = bestCols;
  final rows = (n / cols).ceil();
  final cell = Size(
    (box.width - gap * (cols - 1)) / cols,
    (box.height - gap * (rows - 1)) / rows,
  );

  final origins = <Offset>[];
  for (var i = 0; i < n; i++) {
    final row = i ~/ cols;
    final col = i % cols;
    final inRow = row == rows - 1 ? n - row * cols : cols;
    // Centre a short last row.
    final rowWidth = inRow * cell.width + (inRow - 1) * gap;
    final left = (box.width - rowWidth) / 2;
    origins.add(
      Offset(left + col * (cell.width + gap), row * (cell.height + gap)),
    );
  }
  return MeetGrid(cols, rows, cell, origins);
}
