import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/clubs/rooms/meet_layout.dart';

const phonePortrait = Size(382, 640); // video area on a ~390pt-wide phone
const phoneLandscape = Size(836, 300);
const tablet = Size(1016, 640);

String shape(int n, Size box) {
  final g = meetGrid(n, box);
  return '${g.columns}x${g.rows}';
}

void main() {
  test('two people stack on an upright phone, sit side by side when wide', () {
    expect(shape(2, phonePortrait), '1x2');
    expect(shape(2, phoneLandscape), '2x1');
    expect(shape(2, tablet), '2x1');
  });

  test('grows like Google Meet on an upright phone', () {
    expect(shape(1, phonePortrait), '1x1');
    expect(shape(3, phonePortrait), '2x2');
    expect(shape(4, phonePortrait), '2x2');
    expect(shape(6, phonePortrait), '2x3');
    expect(shape(8, phonePortrait), '2x4');
    expect(shape(9, phonePortrait), '3x3');
    expect(shape(10, phonePortrait), '3x4');
  });

  test('every layout stays inside the box with sensibly shaped tiles', () {
    for (final box in [phonePortrait, phoneLandscape, tablet]) {
      for (var n = 1; n <= 10; n++) {
        final g = meetGrid(n, box);
        expect(g.origins, hasLength(n));
        expect(g.columns * g.rows, greaterThanOrEqualTo(n));
        // No empty full row (would waste a whole band of the screen).
        expect(g.columns * (g.rows - 1), lessThan(n), reason: '$n in $box');
        for (final o in g.origins) {
          expect(o.dx, greaterThanOrEqualTo(-0.01));
          expect(o.dy, greaterThanOrEqualTo(-0.01));
          expect(o.dx + g.cell.width, lessThanOrEqualTo(box.width + 0.01));
          expect(o.dy + g.cell.height, lessThanOrEqualTo(box.height + 0.01));
        }
        // Never the old "tall sliver" look once more than one person is on.
        if (n > 1) {
          final ratio = g.cell.width / g.cell.height;
          expect(ratio, inInclusiveRange(0.5, 1.5), reason: '$n in $box');
        }
      }
    }
  });

  test('a short last row is centred', () {
    final g = meetGrid(3, const Size(800, 600)); // 2x2 with one left over
    expect(g.columns, 2);
    final last = g.origins[2];
    final centredLeft = (800 - g.cell.width) / 2;
    expect(last.dx, closeTo(centredLeft, 0.01));
  });
}
