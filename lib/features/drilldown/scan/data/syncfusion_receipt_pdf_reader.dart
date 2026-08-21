import 'dart:typed_data';

import '../domain/receipt_line_item_parser.dart';
import '../domain/receipt_pdf_reader.dart';
import 'pdf_receipt_parser.dart';
import 'receipt_pdf_words.dart';

class SyncfusionReceiptPdfReader implements ReceiptPdfReader {
  const SyncfusionReceiptPdfReader();

  @override
  ReceiptParseResult? read(Uint8List bytes) {
    final words = extractReceiptWords(bytes);
    if (words.isEmpty) return null;
    return parseReceiptPdf(words);
  }
}
