import 'dart:math' as math;

import 'package:budget_view/features/drilldown/scan/data/receipt_skew.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _size = 400;
const _lineCount = 10;
const _lineSpacing = 30;
const _thickness = 3;

/// A white canvas with dark horizontal-ish stripes drawn at [tiltDegrees].
/// Drawn rather than rotated: rotating a filled canvas pads the corners with
/// pixels that would otherwise pollute the dark-pixel count.
img.Image stripes({required double tiltDegrees}) {
  final image = img.Image(width: _size, height: _size);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  // So a later deskew clears exposed corners to white, not dark, pixels.
  image.backgroundColor = img.ColorRgb8(255, 255, 255);

  final radians = tiltDegrees * math.pi / 180;
  const x0 = 0;
  const x1 = _size - 1;
  final rise = (x1 - x0) * math.tan(radians);

  for (var i = 0; i < _lineCount; i++) {
    final y0 = 20 + i * _lineSpacing;
    final y1 = (y0 + rise).round();
    img.drawLine(
      image,
      x1: x0,
      y1: y0,
      x2: x1,
      y2: y1,
      color: img.ColorRgb8(0, 0, 0),
      thickness: _thickness,
    );
  }
  return image;
}

void main() {
  test('horizontal stripes estimate to roughly zero tilt', () {
    final tilt = estimateReceiptTiltDegrees(stripes(tiltDegrees: 0));

    expect(tilt, closeTo(0, 0.5));
  });

  test('positive tilt in the source estimates as a positive angle', () {
    final tilt = estimateReceiptTiltDegrees(stripes(tiltDegrees: 5));

    expect(tilt, closeTo(5, 1));
    expect(tilt, greaterThan(0));
  });

  test('negative tilt in the source estimates as a negative angle', () {
    final tilt = estimateReceiptTiltDegrees(stripes(tiltDegrees: -7));

    expect(tilt, closeTo(-7, 1));
    expect(tilt, lessThan(0));
  });

  test('deskewReceipt straightens a tilted source below the skip threshold',
      () {
    final deskewed = deskewReceipt(stripes(tiltDegrees: 5));
    final residual = estimateReceiptTiltDegrees(deskewed);

    expect(residual.abs(), lessThan(kMinSkewDegrees));
  });

  test('deskewReceipt returns the same instance when already straight', () {
    final source = stripes(tiltDegrees: 0);

    expect(identical(deskewReceipt(source), source), isTrue);
  });

  test('a blank white image estimates zero tilt', () {
    final image = img.Image(width: _size, height: _size);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));

    expect(estimateReceiptTiltDegrees(image), 0);
  });
}
