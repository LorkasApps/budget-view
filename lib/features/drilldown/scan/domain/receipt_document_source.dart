import 'dart:typed_data';

import 'receipt_image_source.dart';

/// Where a receipt comes from.
///
/// `pdf` is a document, not an image, which is why it has no counterpart in
/// [ScanSource] — the two paths diverge right after picking.
enum ReceiptSource { camera, gallery, pdf }

extension ReceiptSourceImage on ReceiptSource {
  /// The image source this maps onto, or null for a document.
  ScanSource? get asScanSource => switch (this) {
        ReceiptSource.camera => ScanSource.camera,
        ReceiptSource.gallery => ScanSource.gallery,
        ReceiptSource.pdf => null,
      };
}

/// Bytes of one picked document. Never persisted, same as a capture.
class PickedReceiptDocument {
  const PickedReceiptDocument({required this.bytes, this.filename = ''});

  final Uint8List bytes;
  final String filename;
}

abstract interface class ReceiptPdfSource {
  /// Null when the user backs out of the file picker.
  Future<PickedReceiptDocument?> pick();
}
