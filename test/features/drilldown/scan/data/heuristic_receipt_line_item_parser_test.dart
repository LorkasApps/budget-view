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

/// One line of a transcribed dump, with its real rectangle.
OcrLine _at(
  String text,
  double left,
  double top,
  double width,
  double height,
) =>
    OcrLine(text: text, boundingBox: Rect.fromLTWH(left, top, width, height));

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

  group('the real Picnic dump (ticket 055)', () {
    // Every rectangle below was transcribed from the `OcrResult` the app dumped
    // for the failing photo. The block structure is not rebuilt: the parser
    // flattens blocks into lines and never reads a block rectangle.
    final result = _parser.parse(_blocks([_picnicDump]));

    test('every article is paired with its own price', () {
      expect(
        result.candidates.map((c) => c.amountCents),
        [
          479, 375, 1156, 178, 129, 104, 229, 399, 499, 99, //
          1060, 169, 129, 109, 119, 199, 349, 290, 678,
        ],
      );
      // A promotional row prints both prices inside one line (`649 479`), and
      // OCR noise sits inside others (`3% 178`, `11:6 1060`) — the rightmost
      // group decides in all three cases.
      expect(
        result.candidates.fold(0, (sum, c) => sum + c.amountCents!),
        6749,
      );
    });

    test('no position arrives without a description', () {
      // The device reported every row as `Ohne Beschreibung`: the price never
      // shared a band with its article name, so each one parsed as ambiguous.
      expect(
        result.candidates.map((c) => c.parseState),
        everyElement(LineItemParseState.ok),
      );
      expect(result.candidates.first.description, contains('Bratwurst'));
      expect(result.candidates[4].description, contains('Salatgurke'));
    });

    test('the summary block gives the total and the credit, nothing else', () {
      expect(result.printedTotalCents, 6212);
      expect(result.creditCents, 495);
      // OCR misspells the labels — `Bestelung`, `Gespat` — so the skip
      // vocabulary has to match them despite the missing letter.
      expect(
        result.candidates.map((c) => c.description).join(' '),
        allOf(
          isNot(contains('Bestelung')),
          isNot(contains('Gespat')),
          isNot(contains('Betrag')),
        ),
      );
    });

    test('the page header is kept as a diagnostic, not folded into a row', () {
      expect(result.unreadRows, contains('Dein Bon'));
      expect(result.unreadRows, contains('Kantakt'));
      expect(
        result.candidates.map((c) => c.description).join(' '),
        isNot(contains('Dein Bon')),
      );
    });
  });
}

/// The `OcrResult` of the failing Picnic photo, 91 lines, transcribed from the
/// dump the app wrote (ticket 055). The photo itself is never committed.
final _picnicDump = [

  _at('Dein Bon', 15, 6, 94, 17),
  _at('Freitag 17 Juli', 14, 40, 81, 15),
  _at('Alles erneut', 23, 133, 57, 7),
  _at('Ein Problem', 113, 133, 55, 7),
  _at('Bon per Mail', 200, 133, 58, 9),
  _at('Kantakt', 300, 133, 35, 7),
  _at('hinzufügen', 25, 145, 53, 10),
  _at('melden', 123, 145, 34, 8),
  _at('erhalten', 210, 145, 38, 8),
  _at('aufnehme', 291, 145, 47, 8),
  _at('Edeka Regional Bratwurst fein', 94, 201, 183, 12),
  _at('5 Stuck', 96, 218, 32, 7),
  _at('jetzt 4.79E', 98, 235, 51, 9),
  _at('1', 28, 237, 4, 12),
  _at('649 479', 275, 240, 52, 15),
  _at('Edeka Apfel Direktsaft naturtrüb', 94, 288, 197, 12),
  _at('10% Rabatt', 98, 321, 54, 8),
  _at('3', 26, 323, 8, 11),
  _at('47 375', 278, 327, 49, 14),
  _at('Alpro Kokos-Drink Barista', 94, 371, 156, 13),
  _at('Bündel-Bonus', 98, 406, 65, 11),
  _at('1196 1156', 268, 414, 59, 14),
  _at('Delverde Farfalle', 94, 461, 103, 10),
  _at('500g', 94, 478, 24, 10),
  _at('1€ Rabatt', 98, 495, 44, 8),
  _at('2', 26, 497, 8, 11),
  _at('3% 178', 281, 501, 46, 14),
  _at('Salatgurke', 94, 557, 64, 12),
  _at('1stuck mind. 300g', 92, 570, 91, 12),
  _at('129', 305, 587, 22, 15),
  _at('Gut&Günstig Skyr Heidelbeere', 94, 624, 186, 14),
  _at('Holunder', 94, 643, 56, 10),
  _at('SKYR', 35, 655, 23, 8),
  _at('500a', 94, 659, 24, 8),
  _at('1', 28, 670, 5, 12),
  _at('149 104', 281, 674, 46, 13),
  _at('30% Rabatt', 99, 676, 54, 8),
  _at('Gut&Günstig Sahnejoghurt', 94, 722, 162, 11),
  _at('Griechischer Art 10%', 94, 734, 126, 15),
  _at('1ko', 93, 755, 14, 7),
  _at('229', 302, 761, 25, 14),
  _at('Gut&Günstig Hähnchen-Unterkeulen', 94, 817, 224, 11),
  _at('600g', 94, 834, 24, 8),
  _at('399', 301, 847, 26, 13),
  _at('Edeka Regional Premium', 94, 896, 151, 12),
  _at('Rinder-Burger', 93, 909, 85, 16),
  _at('2 x 125g', 96, 929, 36, 9),
  _at('499', 301, 934, 26, 14),
  _at('Gut&Günstig feiner Zucker Raffinade', 94, 990, 224, 11),
  _at('lkg', 94, 1007, 14, 9),
  _at('099', 301, 1021, 26, 14),
  _at('Funny-frisch Chipsfrisch ungarisch', 94, 1068, 215, 12),
  _at('Bündel-Bonus', 97, 1100, 67, 10),
  _at('11:6 1060', 266, 1107, 60, 15),
  _at('Edeka Herzstücke Brioche Burger', 94, 1156, 207, 12),
  _at('Buns', 94, 1172, 30, 10),
  _at('4 Stück', 94, 1188, 35, 8),
  _at('169', 305, 1191, 20, 17),
  _at('Gut&Günstig Bacon', 94, 1250, 118, 11),
  _at('100g', 93, 1267, 23, 9),
  _at('129', 305, 1281, 22, 14),
  _at('Rucola', 94, 1338, 40, 9),
  _at('125q', 93, 1354, 22, 8),
  _at('109', 305, 1368, 22, 14),
  _at('Gut&Günstig Delikatess Jagdwurst', 94, 1424, 212, 12),
  _at('200g', 94, 1440, 24, 9),
  _at('119', 308, 1454, 19, 14),
  _at('Gut&Günstig Kalbsleberwurst', 93, 1507, 181, 14),
  _at('125q', 93, 1527, 22, 8),
  _at('199', 305, 1541, 22, 14),
  _at('Hennes Eier Freilandhaltung', 93, 1594, 172, 14),
  _at('10er Pack', 93, 1614, 45, 7),
  _at('349', 301, 1628, 26, 14),
  _at('Tollettenpapier 3-laglg', 93, 1681, 138, 14),
  _at('8x 200 Blatt', 94, 1701, 60, 7),
  _at('1', 28, 1711, 5, 12),
  _at('290', 302, 1712, 23, 16),
  _at('Dr. Oetker Ristorante Spinaci', 94, 1762, 175, 12),
  _at('390c', 94, 1779, 23, 7),
  _at('Bündel-Bonus', 98, 1793, 67, 12),
  _at('698 678', 276, 1799, 49, 17),
  _at('72.80', 295, 1852, 29, 9),
  _at('Bestelung', 15, 1853, 55, 11),
  _at('Gespat', 14, 1880, 43, 10),
  _at('-5.73', 300, 1880, 26, 9),
  _at('Betrag', 14, 1908, 36, 12),
  _at('67.07', 297, 1908, 30, 9),
  _at('Eingereichtes Pfand v', 15, 1931, 121, 15),
  _at('-4.95', 298, 1936, 28, 9),
  _at('6212', 293, 1968, 33, 15),
  _at('Endsumme', 15, 1970, 78, 11),
];
