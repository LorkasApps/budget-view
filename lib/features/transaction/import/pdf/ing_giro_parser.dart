import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'ing_giro_layout.dart';
import 'parse_result.dart';
import 'pdf_parser.dart';

/// Parser for ING Girokonto statements.
///
/// Only the PDF-to-words step lives here; the table logic is in
/// [parseIngStatement] so it can be tested without a PDF.
class IngGiroParser implements PdfParser {
  const IngGiroParser();

  @override
  String get id => 'ing-giro-v1';

  @override
  String get displayName => 'ING Girokonto';

  @override
  Future<double> canParse(Uint8List bytes) async {
    try {
      final text = _firstPageText(bytes);
      final isIng = text.contains('ING-DiBa AG');
      final isGiro = text.contains('Girokonto');
      return isIng && isGiro ? 0.95 : 0.0;
    } catch (_) {
      return 0.0; // not a PDF, encrypted, or corrupt — simply not ours
    }
  }

  @override
  Future<ParseResult> parse(Uint8List bytes) async =>
      parseIngStatement(_words(bytes));

  String _firstPageText(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document)
          .extractText(startPageIndex: 0, endPageIndex: 0);
    } finally {
      document.dispose();
    }
  }

  List<PositionedWord> _words(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final words = <PositionedWord>[];
      for (final line in PdfTextExtractor(document).extractTextLines()) {
        for (final word in line.wordCollection) {
          words.add(
            PositionedWord(
              page: line.pageIndex,
              left: word.bounds.left,
              top: word.bounds.top,
              text: word.text,
            ),
          );
        }
      }
      return words;
    } finally {
      document.dispose();
    }
  }
}
