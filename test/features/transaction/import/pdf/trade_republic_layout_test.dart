import 'package:budget_view/features/transaction/import/pdf/positioned_word.dart';
import 'package:budget_view/features/transaction/import/pdf/trade_republic_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coordinates and figures are taken from the geometry dump of a real Trade
/// Republic cash statement: date column x=74.4, type x=113.2, description
/// x=157.8, incoming x=368.7, outgoing x=422.8, balance right-aligned near
/// x=479. Amounts arrive with the currency inside one word (`38,71 €`), and a
/// row's date wraps to `01 Juli` 3.8pt above the row's baseline and `2026` 3.8pt
/// below it — which is why a row is one band only above that tolerance. The
/// figures are the real ones, so the balance reconciliation has to hold for the
/// fixture too.
List<PositionedWord> _band(
  double top,
  List<(double, String)> words, {
  int page = 0,
}) {
  return [
    for (final (left, text) in words)
      PositionedWord(page: page, left: left, top: top, text: text),
  ];
}

/// `KONTOÜBERSICHT`: opening 22.281,78 €, closing 21.344,71 €.
List<PositionedWord> _overview({
  String opening = '22.281,78',
  String closing = '21.344,71',
}) {
  return [
    ..._band(241.6, const [
      (74.4, 'PRODUKT'),
      (144.9, 'ANFANGSSALDO'),
      (231.2, 'ZAHLUNGSEINGANG'),
      (334.8, 'ZAHLUNGSAUSGANG'),
      (492.1, 'ENDSALDO'),
    ]),
    ..._band(256.7, [
      (74.4, 'Cashkonto'),
      (144.9, '$opening €'),
      (231.2, '62,93 €'),
      (334.8, '1.000,00 €'),
      (480.7, '$closing €'),
    ]),
  ];
}

List<PositionedWord> _tableHeader(double top) {
  return _band(top, const [
    (74.4, 'DATUM'),
    (113.2, 'TYP'),
    (157.8, 'BESCHREIBUNG'),
    (368.7, 'ZAHLUNGSEINGANG'),
    (422.8, 'ZAHLUNGSAUSGANG'),
    (501.3, 'SALDO'),
  ]);
}

List<PositionedWord> _row(
  double top, {
  required String day,
  required String month,
  required String year,
  required String type,
  required List<String> description,
  required String amount,
  required String balance,
  required bool income,
  List<String> descriptionWrap = const [],
}) {
  // A one-line description sits on the row's baseline; a two-line one straddles
  // it exactly like the date does, which is how the real statement lays out the
  // payee with its IBAN underneath.
  final descriptionTop = descriptionWrap.isEmpty ? top : top - 3.8;
  return [
    ..._band(top - 3.8, [(74.4, day), (84.7, month)]),
    ..._band(descriptionTop, [
      for (final (index, word) in description.indexed)
        (157.8 + index * 30, word),
    ]),
    ..._band(top, [
      (113.2, type),
      (income ? 368.7 : 422.8, '$amount €'),
      (479.2, '$balance €'),
    ]),
    ..._band(top + 3.8, [
      (74.4, year),
      for (final (index, word) in descriptionWrap.indexed)
        (157.8 + index * 30, word),
    ]),
  ];
}

/// The seven cash rows of the real statement, in order.
List<PositionedWord> _cashRows({bool withLastRow = true}) {
  return [
    ..._row(
      560,
      day: '01',
      month: 'Juli',
      year: '2026',
      type: 'Zinsen',
      description: const ['Interest', 'payment'],
      amount: '38,71',
      balance: '22.320,49',
      income: true,
    ),
    ..._row(
      610,
      day: '10',
      month: 'Juli',
      year: '2026',
      type: 'Ertrag',
      description: const ['Cash', 'Dividend', 'for', 'ISIN', 'IE00077FRP95'],
      amount: '6,16',
      balance: '22.326,65',
      income: true,
    ),
    ..._row(
      660,
      day: '15',
      month: 'Juli',
      year: '2026',
      type: 'Ertrag',
      description: const ['Cash', 'Dividend', 'for', 'ISIN', 'US7561091049'],
      amount: '3,03',
      balance: '22.329,68',
      income: true,
    ),
    ..._row(
      710,
      day: '17',
      month: 'Juli',
      year: '2026',
      type: 'Überweisung',
      description: const ['Outgoing', 'transfer', 'for', 'Lukas', 'Kochniss'],
      descriptionWrap: const ['(DE07500105175457672768)'],
      amount: '1.000,00',
      balance: '21.329,68',
      income: false,
    ),
    ..._row(
      760,
      day: '17',
      month: 'Juli',
      year: '2026',
      type: 'Ertrag',
      description: const ['Cash', 'Dividend', 'for', 'ISIN', 'US56035L1044'],
      amount: '2,56',
      balance: '21.332,24',
      income: true,
    ),
    ..._row(
      810,
      day: '17',
      month: 'Juli',
      year: '2026',
      type: 'Ertrag',
      description: const ['Cash', 'Dividend', 'for', 'ISIN', 'IE0002L5QB31'],
      amount: '6,44',
      balance: '21.338,68',
      income: true,
    ),
    if (withLastRow)
      ..._row(
        860,
        day: '31',
        month: 'Juli',
        year: '2026',
        type: 'Ertrag',
        description: const ['Cash', 'Dividend', 'for', 'ISIN', 'IE00077FRP95'],
        amount: '6,03',
        balance: '21.344,71',
        income: true,
      ),
  ];
}

/// Page two: the money-market sweep. Its rows mirror the cash rows, so the
/// parser must not read them — the table carries no `TYP`/`SALDO` header.
List<PositionedWord> _sweepPage() {
  return [
    ..._band(201.5, const [
      (74.4, 'DATUM'),
      (113.2, 'ZAHLUNGSART'),
      (157.8, 'GELDMARKTFONDS'),
      (368.7, 'STÜCK'),
      (422.8, 'KURS'),
      (501.3, 'BETRAG'),
    ], page: 1),
    ..._band(231.5, const [
      (74.4, '02'),
      (84.7, 'Juli'),
      (100.0, '2026'),
      (113.2, 'Kauf'),
      (157.8, 'BNP'),
      (190.0, 'Paribas'),
      (368.7, '38,71'),
      (479.2, '38,71 €'),
    ], page: 1),
  ];
}

void main() {
  test('reads the cash table, signed by its running balance', () {
    final result = parseTradeRepublicStatement([
      ..._overview(),
      ..._tableHeader(534),
      ..._cashRows(),
      ..._band(900, const [(74.4, 'BARMITTELÜBERSICHT')]),
      ..._sweepPage(),
    ]);

    expect(result.warnings, isEmpty);
    expect(result.transactions, hasLength(7));
    expect(result.statementBalanceCents, 2134471);

    final interest = result.transactions.first;
    expect(interest.bookingDate, DateTime(2026, 7, 1));
    expect(interest.amountCents, 3871);
    expect(interest.description, 'Interest payment');
    expect(interest.counterparty, 'Zinsen');
  });

  test('a dividend carries its ISIN as the counterparty', () {
    final result = parseTradeRepublicStatement([
      ..._overview(),
      ..._tableHeader(534),
      ..._cashRows(),
    ]);

    final dividend = result.transactions[1];
    expect(dividend.amountCents, 616);
    expect(dividend.counterparty, 'IE00077FRP95');
    expect(dividend.description, 'Cash Dividend for ISIN IE00077FRP95');
  });

  test('an outgoing transfer is an expense, its payee the counterparty', () {
    final result = parseTradeRepublicStatement([
      ..._overview(),
      ..._tableHeader(534),
      ..._cashRows(),
    ]);

    final transfer = result.transactions[3];
    expect(transfer.amountCents, -100000);
    expect(transfer.counterparty, 'Lukas Kochniss');
    // The IBAN wraps to a second line at the same x as the first word, so this
    // also pins the reading order inside a band.
    expect(
      transfer.description,
      'Outgoing transfer for Lukas Kochniss (DE07500105175457672768)',
    );
  });

  test('the sweep table on the second page contributes nothing', () {
    final withSweep = parseTradeRepublicStatement([
      ..._overview(),
      ..._tableHeader(534),
      ..._cashRows(),
      ..._sweepPage(),
    ]);
    final withoutSweep = parseTradeRepublicStatement([
      ..._overview(),
      ..._tableHeader(534),
      ..._cashRows(),
    ]);

    expect(
      withSweep.transactions.map((c) => c.amountCents),
      withoutSweep.transactions.map((c) => c.amountCents),
    );
  });

  test('two payouts of one position stay distinct bookings', () {
    final result = parseTradeRepublicStatement([
      ..._overview(opening: '0,00', closing: '20,00'),
      ..._tableHeader(534),
      ..._row(
        560,
        day: '10',
        month: 'Juni',
        year: '2026',
        type: 'Ertrag',
        description: const ['Cash', 'Dividend', 'for', 'ISIN', 'IE00077FRP95'],
        amount: '10,00',
        balance: '10,00',
        income: true,
      ),
      ..._row(
        610,
        day: '10',
        month: 'Juli',
        year: '2026',
        type: 'Ertrag',
        description: const ['Cash', 'Dividend', 'for', 'ISIN', 'IE00077FRP95'],
        amount: '10,00',
        balance: '20,00',
        income: true,
      ),
    ]);

    expect(result.warnings, isEmpty);
    // Same amount and counterparty: only the date keeps them apart, and the
    // dedupe hash is built over all three.
    expect(result.transactions.map((c) => c.amountCents), [1000, 1000]);
    expect(result.transactions.map((c) => c.counterparty), [
      'IE00077FRP95',
      'IE00077FRP95',
    ]);
    expect(result.transactions.map((c) => c.bookingDate), [
      DateTime(2026, 6, 10),
      DateTime(2026, 7, 10),
    ]);
  });

  test('a missing row breaks the reconciliation and nothing is imported', () {
    final result = parseTradeRepublicStatement([
      ..._overview(),
      ..._tableHeader(534),
      ..._cashRows(withLastRow: false),
    ]);

    expect(result.transactions, isEmpty);
    expect(result.warnings.single, contains('passt nicht zu Endsaldo'));
    expect(result.statementBalanceCents, 2134471);
  });

  test('an amount that contradicts the balance step is reported', () {
    final result = parseTradeRepublicStatement([
      ..._overview(opening: '0,00', closing: '10,00'),
      ..._tableHeader(534),
      ..._row(
        560,
        day: '10',
        month: 'Juli',
        year: '2026',
        type: 'Zinsen',
        description: const ['Interest', 'payment'],
        amount: '9,00',
        balance: '10,00',
        income: true,
      ),
    ]);

    expect(result.transactions.single.amountCents, 1000);
    expect(result.warnings.single, contains('passt nicht zur Saldoänderung'));
  });

  test('a foreign layout is refused instead of half-parsed', () {
    final result = parseTradeRepublicStatement([
      ..._overview(),
      ..._band(560, const [
        (70.8, '01.07.2026'),
        (141.6, 'Lastschrift'),
        (518.0, '-126,00'),
      ]),
    ]);

    expect(result.transactions, isEmpty);
    expect(result.warnings.single, contains('kein Trade-Republic-Kontoauszug'));
  });

  test('without the overview the direction is unknown, so nothing is read', () {
    final result = parseTradeRepublicStatement([
      ..._tableHeader(534),
      ..._cashRows(),
    ]);

    expect(result.transactions, isEmpty);
    expect(result.warnings.single, contains('Anfangs- und Endsaldo'));
  });
}
