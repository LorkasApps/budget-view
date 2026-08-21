import 'dart:typed_data';

import 'receipt_line_item_parser.dart';

/// Reads positions out of a receipt PDF's text layer.
///
/// Behind an interface for the same reason as [OcrService]: the implementation
/// pulls in Syncfusion, and a flow test has no business carrying a PDF.
abstract interface class ReceiptPdfReader {
  /// Null when the document has no text layer at all — a scan, which belongs in
  /// the OCR path rather than here.
  ReceiptParseResult? read(Uint8List bytes);
}
