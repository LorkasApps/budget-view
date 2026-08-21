import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/receipt_image_source.dart';
import 'receipt_skew.dart';

const _maxEdge = 2000;
const _quality = 85;

/// Downscales a capture to [_maxEdge] and straightens it before OCR, then
/// re-encodes it as JPEG. Runs on a helper isolate — decoding a 12 MP photo on
/// the UI thread drops frames.
///
/// The straightening is what keeps prices on their own rows: the parser groups a
/// description and its price by vertical overlap, and a few degrees of tilt move
/// the right-hand column into the neighbouring row (ticket 035).
class JpegReceiptImagePreprocessor implements ReceiptImagePreprocessor {
  const JpegReceiptImagePreprocessor();

  @override
  Future<Uint8List> prepare(Uint8List bytes) => compute(_prepare, bytes);
}

Uint8List _prepare(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  // Undecodable bytes travel on untouched; OCR reports what it can.
  if (decoded == null) return bytes;

  final scaled = _downscale(decoded);
  final straightened = deskewReceipt(scaled);
  // Nothing changed: re-encoding would only cost quality.
  if (identical(scaled, decoded) && identical(straightened, scaled)) {
    return bytes;
  }
  return img.encodeJpg(straightened, quality: _quality);
}

img.Image _downscale(img.Image decoded) {
  final landscape = decoded.width >= decoded.height;
  final longest = landscape ? decoded.width : decoded.height;
  if (longest <= _maxEdge) return decoded;
  return landscape
      ? img.copyResize(decoded, width: _maxEdge)
      : img.copyResize(decoded, height: _maxEdge);
}
