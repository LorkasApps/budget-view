import 'dart:typed_data';
import 'dart:ui';

/// One recognized line of a receipt.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.boundingBox,
    this.confidence,
  });

  final String text;

  /// In source-image pixels. Receipt heuristics lean on the x-axis: prices sit
  /// right-aligned, quantities left, discount rows indented.
  final Rect boundingBox;

  final double? confidence;
}

/// A paragraph-ish cluster of lines, as ML Kit groups them.
class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.boundingBox,
    this.lines = const [],
  });

  final String text;
  final Rect boundingBox;
  final List<OcrLine> lines;
}

/// Text of one recognized receipt, handed from OCR to the line-item parser.
class OcrResult {
  const OcrResult({this.fullText = '', this.blocks = const []});

  /// The recognizer's own concatenation of everything it found.
  final String fullText;

  final List<OcrBlock> blocks;

  bool get isEmpty => blocks.isEmpty;
}

/// The recognizer itself failed. An empty result is not an error — it travels
/// on and the user decides in the confirm step.
class OcrEngineException implements Exception {
  OcrEngineException(this.message);

  /// German and user-facing.
  final String message;

  @override
  String toString() => 'OcrEngineException: $message';
}

abstract interface class OcrService {
  Future<OcrResult> recognize(Uint8List bytes);
}
