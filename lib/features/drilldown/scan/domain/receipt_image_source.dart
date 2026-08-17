import 'dart:typed_data';

enum ScanSource { camera, gallery }

/// Bytes of one captured receipt. Never persisted — see decisions.md.
class CapturedReceiptImage {
  const CapturedReceiptImage({required this.bytes, this.filename = ''});

  final Uint8List bytes;

  /// Empty for camera captures, which carry no user-facing name.
  final String filename;
}

abstract interface class ReceiptImageSource {
  /// Null when the user backs out of camera or picker.
  Future<CapturedReceiptImage?> pick(ScanSource source);
}

/// Shrinks a capture before OCR. Behind an interface so tests skip the isolate.
abstract interface class ReceiptImagePreprocessor {
  Future<Uint8List> prepare(Uint8List bytes);
}
