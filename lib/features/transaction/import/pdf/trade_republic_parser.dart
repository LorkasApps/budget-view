import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'parse_result.dart';
import 'pdf_parser.dart';
import 'positioned_word.dart';
import 'trade_republic_layout.dart';

/// Parser for the Trade Republic cash statement (Cashkonto).
///
/// Only the PDF-to-words step lives here; the table logic is in
/// [parseTradeRepublicStatement] so it can be tested without a PDF.
class TradeRepublicParser implements PdfParser {
  const TradeRepublicParser();

  @override
  String get id => 'trade-republic-cash-v1';

  @override
  String get displayName => 'Trade Republic Cashkonto';

  @override
  Future<double> canParse(Uint8List bytes) async {
    try {
      final text = _firstPageText(bytes);
      final isTradeRepublic =
          text.contains('TRADE REPUBLIC BANK GMBH') ||
          text.contains('Trade Republic Bank GmbH');
      // The securities and tax documents carry the same letterhead, so the cash
      // table's own heading is what makes this ours.
      final isCashStatement = text.contains('UMSATZÜBERSICHT');
      return isTradeRepublic && isCashStatement ? 0.95 : 0.0;
    } catch (_) {
      return 0.0; // not a PDF, encrypted, or corrupt — simply not ours
    }
  }

  @override
  Future<ParseResult> parse(Uint8List bytes) async =>
      parseTradeRepublicStatement(_words(bytes));

  String _firstPageText(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(
        document,
      ).extractText(startPageIndex: 0, endPageIndex: 0);
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
