import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/clubs/rooms/meet_layout.dart';

const phone = Size(382, 600); // video stage on a ~390pt-wide phone
const smallPhone = Size(312, 480);
const landscape = Size(836, 300);
const tablet = Size(1016, 640);

void main() {
  test('rows grow like a multi-guest live room', () {
    expect(stageRows(1), [1]);
    expect(stageRows(2), [2]);
    expect(stageRows(3), [1, 2]);
    expect(stageRows(4), [2, 2]);
    expect(stageRows(5), [2, 3]);
    expect(stageRows(6), [2, 2, 2]);
    expect(stageRows(7), [2, 3, 2]);
    expect(stageRows(8), [2, 3, 3]);
    expect(stageRows(10), [2, 4, 4]); // the reference screenshot
  });

  test('narrow phones get rows of 3, normal phones rows of 4', () {
    expect(maxPerRowFor(smallPhone.width), 3);
    expect(maxPerRowFor(phone.width), 4);
    expect(stageRows(10, maxPerRow: 3), [2, 3, 3, 2]);
    // Small tiles stay at least ~84pt wide (unless squeezed to fit height).
    final l = stageLayout(10, const Size(312, 900));
    expect(l.tiles[2].width, greaterThanOrEqualTo(minSmallTileWidth));
  });

  test('featured tiles are bigger than the rest', () {
    final l = stageLayout(10, phone);
    expect(l.featuredCount, 2);
    final big = l.tiles[0];
    final small = l.tiles[2];
    expect(big.width, greaterThan(small.width * 1.8));
    expect(big.width, closeTo(big.height, 0.01)); // square featured tiles
  });

  test('every layout fits, centres, and keeps tiles near square', () {
    for (final box in [phone, smallPhone, landscape, tablet]) {
      for (var n = 1; n <= 10; n++) {
        final l = stageLayout(n, box);
        expect(l.tiles, hasLength(n));
        for (final r in l.tiles) {
          expect(r.left, greaterThanOrEqualTo(-0.01), reason: '$n in $box');
          expect(r.top, greaterThanOrEqualTo(-0.01), reason: '$n in $box');
          expect(r.right, lessThanOrEqualTo(box.width + 0.01));
          expect(r.bottom, lessThanOrEqualTo(box.height + 0.01));
          if (n > 1) {
            final ratio = r.width / r.height;
            expect(ratio, inInclusiveRange(0.7, 1.4), reason: '$n in $box');
          }
        }
        // Tiles never overlap.
        for (var i = 0; i < n; i++) {
          for (var j = i + 1; j < n; j++) {
            final o = l.tiles[i].intersect(l.tiles[j]);
            expect(o.width <= 0.01 || o.height <= 0.01, isTrue);
          }
        }
        // Block is vertically centred.
        final top = l.tiles.map((r) => r.top).reduce((a, b) => a < b ? a : b);
        final bottom = l.tiles
            .map((r) => r.bottom)
            .reduce((a, b) => a > b ? a : b);
        expect(top, closeTo(box.height - bottom, 0.5), reason: '$n in $box');
      }
    }
  });

  test('a short row is centred', () {
    final l = stageLayout(5, phone); // [2, 3]
    final third = l.tiles[2];
    final last = l.tiles[4];
    expect(third.left, closeTo(phone.width - last.right, 0.5));
  });
}
