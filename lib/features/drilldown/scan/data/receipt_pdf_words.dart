import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// One word of a PDF's text layer with the box it occupies.
///
/// Coordinates are Syncfusion's: origin top-left, so a larger [top] means
/// further **down** the page. The receipt parser leans on that — of two prices in
/// one block, the lower one is the one that counts.
@immutable
class ReceiptWord {
  const ReceiptWord({
    required this.page,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.text,
  });

  final int page;
  final double left;
  final double top;
  final double width;
  final double height;
  final String text;

  double get right => left + width;
  double get bottom => top + height;
  double get centerY => top + height / 2;
}

/// Text-layer words of a PDF, in document order.
///
/// Empty when the document carries no text layer at all — a scan, which the
/// caller has to route through OCR instead of trying to parse.
List<ReceiptWord> extractReceiptWords(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    final words = <ReceiptWord>[];
    for (final line in PdfTextExtractor(document).extractTextLines()) {
      for (final word in line.wordCollection) {
        // Syncfusion pads word text with spaces; see errors.md.
        final text = word.text.trim();
        if (text.isEmpty) continue;
        words.add(
          ReceiptWord(
            page: line.pageIndex,
            left: word.bounds.left,
            top: word.bounds.top,
            width: word.bounds.width,
            height: word.bounds.height,
            text: text,
          ),
        );
      }
    }
    return words;
  } finally {
    document.dispose();
  }
}
