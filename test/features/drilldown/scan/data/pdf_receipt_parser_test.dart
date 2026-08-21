import 'package:budget_view/features/drilldown/scan/data/pdf_receipt_parser.dart';
import 'package:budget_view/features/drilldown/scan/data/receipt_pdf_words.dart';
import 'package:flutter_test/flutter_test.dart';

const double _height = 8;
const double _charWidth = 6;
const double _priceLeft = 430;

/// Words from (left, top, text) triples, all on page 0 at a shared [height] —
/// the median height the parser derives its clustering tolerance from.
List<ReceiptWord> _words(
  List<(double, double, String)> specs, {
  double height = _height,
}) => [
  for (final (left, top, text) in specs)
    ReceiptWord(
      page: 0,
      left: left,
      top: top,
      width: text.length * _charWidth,
      height: height,
      text: text,
    ),
];

/// A printed price as three separate words: the integer, a period slightly
/// below its baseline and the cents slightly above it — reassembled left to
/// right, the last two digits are the cents.
List<ReceiptWord> _priceBand({
  required double top,
  required int amount,
  required int cents,
  double left = _priceLeft,
  double height = _height,
}) {
  final integerText = '$amount';
  final centsText = cents.toString().padLeft(2, '0');
  return [
    ReceiptWord(
      page: 0,
      left: left,
      top: top,
      width: integerText.length * _charWidth,
      height: height,
      text: integerText,
    ),
    ReceiptWord(
      page: 0,
      left: left + _charWidth,
      top: top + 1,
      width: _charWidth * 0.5,
      height: height,
      text: '.',
    ),
    ReceiptWord(
      page: 0,
      left: left + 11,
      top: top - 1,
      width: centsText.length * _charWidth,
      height: height,
      text: centsText,
    ),
  ];
}

void main() {
  test(
    'clusters a two-line item by vertical proximity and splits on a far gap',
    () {
      final words = [
        ..._words([(212, 100, 'Apfel'), (212, 110, 'Rot')]),
        ..._priceBand(top: 119, amount: 1, cents: 99),
        ..._words([(212, 160, 'Banane')]),
        ..._priceBand(top: 163, amount: 2, cents: 99),
      ];

      final result = parseReceiptPdf(words);

      expect(result.candidates, hasLength(2));
      expect(result.candidates[0].description, 'Apfel Rot');
      expect(result.candidates[0].amountCents, 199);
      expect(result.candidates[1].description, 'Banane');
      expect(result.candidates[1].amountCents, 299);
    },
  );

  test(
    'reassembles a price from its separate integer, cents and period words',
    () {
      final words = [
        ..._words([(212, 100, 'Testartikel')]),
        ..._priceBand(top: 100, amount: 3, cents: 79),
      ];

      final candidate = parseReceiptPdf(words).candidates.single;

      expect(candidate.amountCents, 379);
    },
  );

  test('takes the bottom-most price band when a block holds two', () {
    final words = [
      ..._words([(212, 100, 'Testartikel')]),
      ..._priceBand(top: 103, amount: 5, cents: 99), // struck-through original
      ..._priceBand(
        top: 116,
        amount: 3,
        cents: 79,
      ), // the price that replaced it
    ];

    final candidate = parseReceiptPdf(words).candidates.single;

    expect(candidate.amountCents, 379);
  });

  test('reads a lone number at the left edge of a block as the quantity', () {
    final words = [
      ..._words([(149, 100, '2'), (212, 100, 'Apfel')]),
      ..._priceBand(top: 100, amount: 1, cents: 99),
    ];

    final candidate = parseReceiptPdf(words).candidates.single;

    expect(candidate.quantity, 2);
    expect(candidate.description, 'Apfel');
  });

  test('keeps a number glued to its own word out of the quantity field', () {
    final words = [
      ..._words([
        (212, 100, 'Röstkaffee'),
        (290, 100, '1'),
        (300, 100, 'Stück'),
      ]),
      ..._priceBand(top: 100, amount: 4, cents: 49),
    ];

    final candidate = parseReceiptPdf(words).candidates.single;

    expect(candidate.quantity, isNull);
    expect(candidate.description, 'Röstkaffee 1 Stück');
  });

  test('glues a ligature break but keeps a real space', () {
    final words = [
      ..._words([
        (212, 100, 'Bio'),
        (234, 100, 'Röstkaf'), // normal gap: stays a separate word
        (276, 100, 'fee'), // zero gap: the PDF split mid-word
      ]),
      ..._priceBand(top: 100, amount: 5, cents: 99),
    ];

    final candidate = parseReceiptPdf(words).candidates.single;

    expect(candidate.description, 'Bio Röstkaffee');
  });

  test('drops a block with no amount, like an address', () {
    final words = _words([(212, 100, 'Musterstraße'), (212, 111, '12')]);

    final result = parseReceiptPdf(words);

    expect(result.candidates, isEmpty);
  });

  test(
    'reads the total and credits, and drops a row above the printed total',
    () {
      final words = [
        ..._words([(212, 100, 'Apfel')]),
        ..._priceBand(top: 100, amount: 1, cents: 99),
        ..._words([(212, 140, 'Gesamtbetrag')]),
        ..._priceBand(top: 140, amount: 20, cents: 50),
        ..._words([(212, 180, 'Eingereichtes'), (300, 180, 'Geld')]),
        ..._priceBand(top: 180, amount: 50, cents: 0),
        ..._words([(212, 220, 'Bestellnummer')]),
        ..._priceBand(top: 220, amount: 99, cents: 99), // more than the total
      ];

      final result = parseReceiptPdf(words);

      expect(result.printedTotalCents, 2050);
      expect(result.creditCents, 5000);
      expect(result.expectedPositionSumCents, 7050);
      expect(result.candidates, hasLength(1));
      expect(result.candidates.single.description, 'Apfel');
      expect(result.candidates.single.amountCents, 199);
    },
  );

  test('skips subtotal, tax and savings rows', () {
    final words = [
      ..._words([(212, 100, 'Zwischensumme')]),
      ..._priceBand(top: 100, amount: 10, cents: 0),
      ..._words([(212, 140, 'Mwst')]),
      ..._priceBand(top: 140, amount: 1, cents: 90),
      ..._words([(212, 180, 'Du'), (234, 180, 'sparst')]),
      ..._priceBand(top: 180, amount: 2, cents: 50),
    ];

    final result = parseReceiptPdf(words);

    expect(result.candidates, isEmpty);
  });

  test('an empty word list produces an empty result without throwing', () {
    final result = parseReceiptPdf(const []);

    expect(result.candidates, isEmpty);
    expect(result.printedTotalCents, isNull);
    expect(result.creditCents, 0);
  });
}
