import 'dart:ui';

import 'package:budget_view/features/drilldown/scan/data/heuristic_receipt_line_item_parser.dart';
import 'package:budget_view/features/drilldown/scan/domain/ocr_service.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_line_item_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// One OCR line at a given vertical band, left-aligned at [left].
OcrLine _line(String text, {required double top, double left = 0}) =>
    OcrLine(
      text: text,
      boundingBox: Rect.fromLTWH(left, top, 60, 20),
    );

/// Wraps each list of lines in its own block — ML Kit's usual split between a
/// description column and a price column.
OcrResult _blocks(List<List<OcrLine>> blocks) => OcrResult(
      blocks: [
        for (final lines in blocks)
          OcrBlock(text: '', boundingBox: Rect.zero, lines: lines),
      ],
    );

/// A single OCR row, as one line in one block.
OcrResult _row(String text) => _blocks([[_line(text, top: 0)]]);

const _parser = HeuristicReceiptLineItemParser();

void main() {
  test('lines split across blocks merge into one row by vertical overlap',
      () {
    final description = _line('Milch', top: 10, left: 0);
    final price = _line('1,19', top: 12, left: 200);
    final farBelow = _line('Brot 2,49', top: 100, left: 0);

    final result =
        _parser.parse(_blocks([[description], [price], [farBelow]]));
    final candidates = result.candidates;

    expect(candidates, hasLength(2));
    expect(candidates[0].description, 'Milch');
    expect(candidates[0].amountCents, 119);
    expect(candidates[1].description, 'Brot');
    expect(candidates[1].amountCents, 249);
  });

  test('currency variants all parse to the right cents', () {
    const cases = {
      '1,23': 123,
      '1.23': 123,
      '1234,56': 123456,
      '1.234,56': 123456,
      '1 234,56': 123456,
      '€ 1,23': 123,
      '1,23 €': 123,
    };

    for (final entry in cases.entries) {
      final candidate =
          _parser.parse(_row('Ware ${entry.key}')).candidates.single;
      expect(candidate.amountCents, entry.value, reason: entry.key);
    }
  });

  test('the thousands separator is stripped, not read as a decimal point',
      () {
    final candidate = _parser.parse(_row('Ware 1.234,56')).candidates.single;

    expect(candidate.amountCents, 123456);
  });

  test('the rightmost money token in a row wins', () {
    final candidate = _parser.parse(_row('2x 0,89 1,78')).candidates.single;

    expect(candidate.amountCents, 178);
  });

  test('a leading count is consumed, a leading measure keeps its unit', () {
    final milk = _parser.parse(_row('2x Milch 1,78')).candidates.single;
    expect(milk.quantity, 2);
    expect(milk.description, 'Milch');

    final rolls = _parser.parse(_row('3 Stk Brötchen 1,50')).candidates.single;
    expect(rolls.quantity, 3);
    expect(rolls.description, 'Brötchen');

    // `LineItem` has no unit field, so the parser leaves "kg" in the
    // description rather than discard it.
    final apples = _parser.parse(_row('1,5 kg Äpfel 4,49')).candidates.single;
    expect(apples.quantity, 1.5);
    expect(apples.description, 'kg Äpfel');
  });

  test('unit price is derived only when it lands within a cent', () {
    final milk = _parser.parse(_row('2x Milch 1,78')).candidates.single;
    expect(milk.unitPriceCents, 89);

    final mismatch = _parser.parse(_row('7x Sample 1,00')).candidates.single;
    expect(mismatch.unitPriceCents, isNull);
  });

  test('skip-list rows produce no candidate regardless of case', () {
    final rows = [
      'Summe 12,34',
      'MWST 19% 1,23',
      'Gegeben 20,00',
      'ec-cash 12,34',
      'DATUM 01.08.2026',
    ];
    final lines = [
      for (var i = 0; i < rows.length; i++) _line(rows[i], top: i * 100.0),
    ];

    final candidates = _parser.parse(_blocks([lines])).candidates;

    expect(candidates, isEmpty);
  });

  test('a row without a money token yields no candidate at all', () {
    expect(_parser.parse(_row('Vielen Dank')).candidates, isEmpty);
  });

  test('a row that is only an amount is ambiguous', () {
    final candidate = _parser.parse(_row('1,99')).candidates.single;

    expect(candidate.parseState, LineItemParseState.ambiguous);
    expect(candidate.includeInSave, isFalse);
  });

  test('an empty OcrResult yields no candidates', () {
    expect(_parser.parse(const OcrResult()).candidates, isEmpty);
  });

  test('a skipped total row surfaces its amount as the printed total', () {
    final result = _parser.parse(_row('Gesamtpreis 12,34'));

    expect(result.candidates, isEmpty);
    expect(result.printedTotalCents, 1234);
  });

  test('a zwischensumme row is skipped but is not read as the total', () {
    final result = _parser.parse(_row('Zwischensumme 5,00'));

    expect(result.candidates, isEmpty);
    expect(result.printedTotalCents, isNull);
  });

  test('a bargeld row is skipped', () {
    expect(_parser.parse(_row('Bargeld 20,00')).candidates, isEmpty);
  });

  test('no total row leaves printedTotalCents null', () {
    expect(_parser.parse(_row('Milch 1,19')).printedTotalCents, isNull);
  });

  test('of two total rows, the later one wins', () {
    final lines = [
      _line('Summe 10,00', top: 0),
      _line('Gesamt 12,50', top: 100),
    ];

    final result = _parser.parse(_blocks([lines]));

    expect(result.printedTotalCents, 1250);
  });

  group('rules borrowed from the PDF parser (ticket 043)', () {
    test('a promotional row takes the lower of two stacked prices', () {
      // Both prices are right-aligned, so only their vertical order tells the
      // struck-through original from the price that replaced it.
      final description = _line('Bio Milch', top: 10, left: 0);
      final struckThrough = _line('4,29', top: 8, left: 200);
      final realPrice = _line('3,79', top: 14, left: 200);

      final result = _parser.parse(
        _blocks([
          [description],
          [struckThrough],
          [realPrice],
        ]),
      );

      final candidate = result.candidates.single;
      expect(candidate.amountCents, 379);
      expect(candidate.description, 'Bio Milch');
    });

    test('a returned deposit becomes a credit, not a position', () {
      final lines = [
        _line('Milch 1,19', top: 0),
        _line('Eingereichtes Pfand 2,50', top: 100),
        _line('Summe 10,00', top: 200),
      ];

      final result = _parser.parse(_blocks([lines]));

      expect(result.candidates.single.description, 'Milch');
      expect(result.creditCents, 250);
      expect(result.printedTotalCents, 1000);
      // The positions only reconcile once the credit is added back.
      expect(result.expectedPositionSumCents, 1250);
    });

    test('a returned deposit lifts the bound above the printed total', () {
      // The deposit is already deducted from what was paid, so the positions sum
      // higher than the printed total — bounding against the total alone would
      // drop this item.
      final lines = [
        _line('Kiste Wasser 5,00', top: 0),
        _line('Eingereichtes Pfand 3,30', top: 100),
        _line('Summe 1,70', top: 200),
      ];

      final result = _parser.parse(_blocks([lines]));

      expect(result.candidates.single.amountCents, 500);
      expect(result.expectedPositionSumCents, 500);
    });

    test('nothing may cost more than the printed total', () {
      final lines = [
        _line('Milch 1,19', top: 0),
        // Page furniture whose digits happen to read as an amount.
        _line('Kundennr 4711 99,99', top: 50),
        _line('Summe 1,19', top: 100),
      ];

      final result = _parser.parse(_blocks([lines]));

      expect(result.candidates.single.amountCents, 119);
    });

    test('the bound only applies once a total was printed', () {
      final lines = [
        _line('Milch 1,19', top: 0),
        _line('Teure Ware 99,99', top: 100),
      ];

      final result = _parser.parse(_blocks([lines]));

      expect(result.candidates.map((c) => c.amountCents), [119, 9999]);
    });

    test('raised cents are reassembled into one price (ticket 045)', () {
      // Picnic prints the cents raised: `3` and `79` sit on their own baselines in
      // the price column, so neither half is a money token on its own.
      final result = _parser.parse(
        _blocks([
          [_line('H-Milch 1,5%', top: 100, left: 0)],
          [_line('3', top: 100, left: 300)],
          [_line('79', top: 96, left: 316)],
          [_line('Endsumme 3,79', top: 200, left: 0)],
        ]),
      );

      final candidate = result.candidates.single;
      expect(candidate.amountCents, 379);
      expect(candidate.description, 'H-Milch 1,5%');
    });

    test('Endsumme is read as the total, not as a position', () {
      // German puts the keyword at the end of a compound, which a prefix rule
      // misses — and without a total there is no checksum and no bound.
      final result = _parser.parse(_row('Endsumme 12,34'));

      expect(result.candidates, isEmpty);
      expect(result.printedTotalCents, 1234);
    });

    test('Zwischensumme still is not the total', () {
      final result = _parser.parse(_row('Zwischensumme 5,00'));

      expect(result.candidates, isEmpty);
      expect(result.printedTotalCents, isNull);
    });

    test('a row without a usable amount is kept as a diagnostic', () {
      final result = _parser.parse(
        _blocks([
          [_line('Milch 1,19', top: 0)],
          [_line('Bernard-Eyberg-Straße 80a', top: 100)],
        ]),
      );

      expect(result.candidates.single.description, 'Milch');
      expect(result.unreadRows, ['Bernard-Eyberg-Straße 80a']);
    });

    test('a receipt that reads cleanly reports no unread rows', () {
      final result = _parser.parse(_row('Milch 1,19'));

      expect(result.unreadRows, isEmpty);
    });

    test('the summary block of a delivery receipt yields no positions', () {
      // The real block of a Picnic receipt, ticket 055. Only `Endsumme` is the
      // total and only `Eingereichtes Pfand` a credit; the other three carry a
      // money token each and used to arrive as items.
      final result = _parser.parse(
        _blocks([
          [_line('Bio Milch 1,19', top: 0)],
          [_line('Bestellung 72,80', top: 100)],
          [_line('Gespart -5,73', top: 150)],
          [_line('Betrag 67,07', top: 200)],
          [_line('Eingereichtes Pfand 4,95', top: 250)],
          [_line('Endsumme 62,12', top: 300)],
        ]),
      );

      expect(result.candidates.map((c) => c.description), ['Bio Milch']);
      expect(result.printedTotalCents, 6212);
      expect(result.creditCents, 495);
    });

    test('a Rabatt badge beside a reduced item is not a position', () {
      final result = _parser.parse(
        _blocks([
          [_line('Bratwurst 4,79', top: 0)],
          [_line('Rabatt 6,79', top: 60)],
          [_line('Endsumme 4,79', top: 120)],
        ]),
      );

      expect(result.candidates.map((c) => c.amountCents), [479]);
    });

    test('a row as large as the whole receipt is dropped', () {
      final result = _parser.parse(
        _blocks([
          [_line('Milch 1,19', top: 0)],
          [_line('Brot 2,00', top: 100)],
          // Exactly the budget, so the plausibility bound lets it pass — this is
          // the gap `Betrag 67,07` slipped through on the real receipt.
          [_line('Zwischenzeile 3,19', top: 200)],
          [_line('Endsumme 3,19', top: 300)],
        ]),
      );

      expect(result.candidates.map((c) => c.description), ['Milch', 'Brot']);
    });

    test('a single article may equal the receipt total', () {
      final result = _parser.parse(
        _blocks([
          [_line('Milch 1,19', top: 0)],
          [_line('Endsumme 1,19', top: 100)],
        ]),
      );

      expect(result.candidates.single.amountCents, 119);
    });

    test('a credit row without a total still counts as a credit', () {
      final result = _parser.parse(_row('Gutschrift 3,00'));

      expect(result.candidates, isEmpty);
      expect(result.creditCents, 300);
      expect(result.expectedPositionSumCents, isNull);
    });
  });
}
