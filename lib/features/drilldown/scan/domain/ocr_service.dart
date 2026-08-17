import 'dart:typed_data';

/// Text of one recognized receipt, handed from OCR to the line-item parser.
///
/// Ticket 017 owns the recognizer; the shape lives here because the scan flow
/// is its only caller.
class OcrResult {
  const OcrResult({this.lines = const []});

  /// Recognized text, one entry per receipt line, top to bottom.
  final List<String> lines;

  bool get isEmpty => lines.isEmpty;
}

abstract interface class OcrService {
  Future<OcrResult> recognize(Uint8List bytes);
}

/// Recognizes nothing — placeholder until ticket 017 wires Google ML Kit.
class NoOcrService implements OcrService {
  const NoOcrService();

  @override
  Future<OcrResult> recognize(Uint8List bytes) async => const OcrResult();
}
