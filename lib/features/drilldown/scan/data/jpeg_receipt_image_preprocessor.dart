import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/receipt_image_source.dart';

const _maxEdge = 2000;
const _quality = 85;

/// Downscales a capture to [_maxEdge] and re-encodes it as JPEG so OCR stays
/// fast. Runs on a helper isolate — decoding a 12 MP photo on the UI thread
/// drops frames.
class JpegReceiptImagePreprocessor implements ReceiptImagePreprocessor {
  const JpegReceiptImagePreprocessor();

  @override
  Future<Uint8List> prepare(Uint8List bytes) => compute(_downscale, bytes);
}

Uint8List _downscale(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  // Undecodable bytes travel on untouched; OCR reports what it can.
  if (decoded == null) return bytes;

  final landscape = decoded.width >= decoded.height;
  final longest = landscape ? decoded.width : decoded.height;
  // Already small enough: re-encoding would only cost quality.
  if (longest <= _maxEdge) return bytes;

  final resized = landscape
      ? img.copyResize(decoded, width: _maxEdge)
      : img.copyResize(decoded, height: _maxEdge);
  return img.encodeJpg(resized, quality: _quality);
}
