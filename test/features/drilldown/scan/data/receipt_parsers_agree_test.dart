import 'dart:ui';

import 'package:budget_view/features/drilldown/scan/data/heuristic_receipt_line_item_parser.dart';
import 'package:budget_view/features/drilldown/scan/data/pdf_receipt_parser.dart';
import 'package:budget_view/features/drilldown/scan/data/receipt_pdf_words.dart';
import 'package:budget_view/features/drilldown/scan/domain/ocr_service.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_line_item_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same receipt, once as OCR lines and once as PDF words: one promotional item
/// whose struck-through original sits above the real price, one returned deposit,
/// and the printed total. Ticket 043 moved the rules both parsers share into one
/// place, and this is what says they actually agree.
const _priceLeft = 430.0;

OcrResult _ocrReceipt() {
  OcrLine line(String text, {required double top, double left = 100}) =>
      OcrLine(text: text, boundingBox: Rect.fromLTWH(left, top, 60, 20));

  return OcrResult(
    blocks: [
      for (final lines in [
        [line('Bio Milch', top: 100)],
        [line('4,29', top: 96, left: _priceLeft)],
        [line('3,79', top: 106, left: _priceLeft)],
        [line('Eingereichtes Pfand 2,50', top: 160)],
        [line('Summe 1,29', top: 220)],
      ])
        OcrBlock(text: '', boundingBox: Rect.zero, lines: lines),
    ],
  );
}

List<ReceiptWord> _pdfReceipt() {
  ReceiptWord word(double left, double top, String text) => ReceiptWord(
    page: 0,
    left: left,
    top: top,
    width: text.length * 6,
    height: 8,
    text: text,
  );

  return [
    word(100, 100, 'Bio'),
    word(130, 100, 'Milch'),
    word(_priceLeft, 96, '4.29'),
    word(_priceLeft, 106, '3.79'),
    word(100, 160, 'Eingereichtes'),
    word(200, 160, 'Pfand'),
    word(_priceLeft, 160, '2.50'),
    word(100, 220, 'Summe'),
    word(_priceLeft, 220, '1.29'),
  ];
}

void main() {
  test('both parsers read the same receipt the same way', () {
    final fromPhoto = const HeuristicReceiptLineItemParser().parse(
      _ocrReceipt(),
    );
    final fromPdf = parseReceiptPdf(_pdfReceipt());

    void expectTheReceipt(ReceiptParseResult result, String source) {
      expect(
        result.candidates.map((c) => (c.description, c.amountCents)),
        [('Bio Milch', 379)],
        reason: source,
      );
      expect(result.creditCents, 250, reason: source);
      expect(result.printedTotalCents, 129, reason: source);
      // Positions reconcile against the printed total once the returned deposit
      // is added back — the same figure on both paths.
      expect(result.expectedPositionSumCents, 379, reason: source);
    }

    expectTheReceipt(fromPhoto, 'photo');
    expectTheReceipt(fromPdf, 'pdf');
  });
}
