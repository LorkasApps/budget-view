import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Widest tilt still corrected. Beyond this a hand-held photo is crooked enough
/// that a projection profile starts locking onto the wrong structure.
const double kMaxSkewDegrees = 12;

/// Search step. Half a degree is below what shifts a price into the neighbouring
/// row across a receipt's width.
const double kSkewStepDegrees = 0.5;

/// Below this the rotation is skipped: resampling for a fraction of a degree
/// costs sharpness and buys nothing.
const double kMinSkewDegrees = 0.25;

/// Longest edge the estimate runs on. The angle does not get better with more
/// pixels, and every candidate angle walks the whole point set.
const int _estimateMaxEdge = 600;

/// Tilt of the text lines in degrees, positive when rows run downwards to the
/// right. Zero when nothing usable was found.
///
/// Projection profile: dark pixels are accumulated into bins along the candidate
/// baseline direction, and the angle whose profile concentrates hardest wins.
/// The bins are computed from the point coordinates rather than by rotating the
/// bitmap once per angle, which is what makes the search affordable.
double estimateReceiptTiltDegrees(
  img.Image source, {
  double maxDegrees = kMaxSkewDegrees,
  double stepDegrees = kSkewStepDegrees,
}) {
  final small = _downscaleForEstimate(source);
  final points = _darkPoints(small);
  // Too little ink to reason about — a blank or blown-out capture.
  if (points.length < 200) return 0;

  var bestAngle = 0.0;
  var bestScore = -1.0;
  for (var angle = -maxDegrees; angle <= maxDegrees + 1e-9; angle += stepDegrees) {
    final score = _profileScore(points, small.width, small.height, angle);
    if (score > bestScore) {
      bestScore = score;
      bestAngle = angle;
    }
  }
  return bestAngle;
}

/// Straightened copy, or [source] itself when the tilt is negligible.
///
/// Rotation exposes new corners, and `copyRotate` clears them with the image's
/// background colour — black by default, which would put a large dark mass on a
/// picture of white paper and skew any later estimate. Paper white is the honest
/// fill here.
img.Image deskewReceipt(img.Image source) {
  final tilt = estimateReceiptTiltDegrees(source);
  if (tilt.abs() < kMinSkewDegrees) return source;
  source.backgroundColor = img.ColorRgb8(255, 255, 255);
  return img.copyRotate(source, angle: -tilt);
}

img.Image _downscaleForEstimate(img.Image source) {
  final longest = math.max(source.width, source.height);
  if (longest <= _estimateMaxEdge) return source;
  return source.width >= source.height
      ? img.copyResize(source, width: _estimateMaxEdge)
      : img.copyResize(source, height: _estimateMaxEdge);
}

/// Coordinates of pixels darker than the image mean, which on a receipt is ink.
/// The mean is used rather than a fixed threshold because captures vary in
/// exposure far more than in contrast.
List<int> _darkPoints(img.Image image) {
  final width = image.width;
  final height = image.height;

  var sum = 0.0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      sum += image.getPixel(x, y).luminance;
    }
  }
  final threshold = (sum / (width * height)) * 0.75;

  // Flat x,y pairs: one list of ints beats a list of objects for a set this size.
  final points = <int>[];
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (image.getPixel(x, y).luminance < threshold) {
        points
          ..add(x)
          ..add(y);
      }
    }
  }
  return points;
}

double _profileScore(List<int> points, int width, int height, double degrees) {
  final radians = degrees * math.pi / 180;
  final cos = math.cos(radians);
  final sin = math.sin(radians);

  // Projected coordinate of any point stays within these bounds.
  final span = (height * cos.abs() + width * sin.abs()).ceil() + 1;
  final offset = (width * sin.abs()).ceil();
  final bins = List<int>.filled(span + offset + 1, 0);

  for (var i = 0; i < points.length; i += 2) {
    final projected = points[i + 1] * cos - points[i] * sin;
    bins[projected.round() + offset]++;
  }

  // Sum of squares: aligned rows crowd into few bins, which raises it.
  var score = 0.0;
  for (final count in bins) {
    score += count * count.toDouble();
  }
  return score;
}
