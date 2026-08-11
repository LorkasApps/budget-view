import 'package:budget_view/features/transaction/import/pdf/ing_giro_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coordinates mirror a real ING statement as reported by the PDF text layer:
/// date column x≈71, description x≈142, amount right-aligned from x≈494,
/// header at `Buchung | Buchung / Verwendungszweck | Betrag EUR`, rows ~12pt apart.
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

List<PositionedWord> _header({int page = 0, double top = 340.8}) {
  return _band(top, const [
    (70.8, 'Buchung'),
    (141.6, 'Buchung'),
    (185.0, '/'),
    (191.0, 'Verwendungszweck'),
    (493.8, 'Betrag'),
    (527.0, 'EUR'),
  ], page: page);
}

void main() {
  test('reads bookings, valuta, description and closing balance', () {
    final words = <PositionedWord>[
      ..._band(216.7, const [
        (312.0, 'Neuer'),
        (342.0, 'Saldo'),
        (488.0, '2.927,04'),
        (531.0, 'Euro'),
      ]),
      ..._header(),
      ..._band(372.1, const [
        (70.8, '01.07.2026'),
        (141.6, 'Lastschrift'),
        (195.0, 'Belkaw'),
        (229.0, 'GmbH'),
        (518.0, '-126,00'),
      ]),
      ..._band(384.5, const [
        (70.8, '02.07.2026'),
        (141.6, '257.234.594-2'),
        (210.0, 'Abschlag'),
      ]),
      ..._band(397.4, const [
        (141.6, 'Mandat:'),
        (181.0, 'ML93000000006806'),
      ]),
      ..._band(409.7, const [
        (141.6, 'Referenz:'),
        (186.0, '93V-L2026-0000432323'),
      ]),
      ..._band(483.4, const [
        (70.8, '01.07.2026'),
        (141.6, 'Gutschrift/Dauerauftrag'),
        (259.0, 'Linda'),
        (321.0, 'Kochniss'),
        (533.0, '8,00'),
      ]),
      ..._band(495.8, const [
        (70.8, '01.07.2026'),
        (141.6, 'Handyvertrag'),
      ]),
    ];

    final result = parseIngStatement(words);

    expect(result.warnings, isEmpty);
    expect(result.statementBalanceCents, 292704);
    expect(result.transactions.length, 2);

    final debit = result.transactions.first;
    expect(debit.amountCents, -12600);
    expect(debit.bookingDate, DateTime(2026, 7, 1));
    expect(debit.valueDate, DateTime(2026, 7, 2));
    expect(debit.counterparty, 'Belkaw GmbH');
    expect(debit.description, '257.234.594-2 Abschlag');
    expect(debit.raw['type'], 'Lastschrift');
    expect(debit.raw['mandate'], 'ML93000000006806');
    expect(debit.raw['reference'], '93V-L2026-0000432323');
    expect(debit.raw['page'], '1');

    final credit = result.transactions.last;
    expect(credit.amountCents, 800);
    expect(credit.counterparty, 'Linda Kochniss');
    expect(credit.description, 'Handyvertrag');
    expect(credit.raw['type'], 'Gutschrift/Dauerauftrag');
  });

  test('ignores a footnote marker sitting right of the amount', () {
    final words = <PositionedWord>[
      ..._header(),
      ..._band(557.2, const [
        (70.8, '01.07.2026'),
        (141.6, 'Entgelt'),
        (179.0, 'VISA'),
        (529.0, '-0,48'),
        (552.6, '1'),
      ]),
      ..._band(569.9, const [
        (70.8, '30.06.2026'),
        (141.6, 'AUSLANDSEINSATZENTGELT'),
      ]),
    ];

    final result = parseIngStatement(words);

    expect(result.transactions.single.amountCents, -48);
    expect(result.transactions.single.valueDate, DateTime(2026, 6, 30));
    expect(result.warnings, isEmpty);
  });

  test('skips the vertical document marker left of the table', () {
    final marker = <PositionedWord>[
      for (var i = 0; i < 6; i++)
        PositionedWord(page: 0, left: 29.1, top: 700.0 + i * 5.5, text: 'X'),
    ];

    final result = parseIngStatement([
      ..._header(),
      ..._band(372.1, const [
        (70.8, '01.07.2026'),
        (141.6, 'Lastschrift'),
        (195.0, 'REWE'),
        (523.0, '-6,47'),
      ]),
      ...marker,
    ]);

    expect(result.transactions.single.amountCents, -647);
    expect(result.transactions.single.description, 'Lastschrift');
    expect(result.warnings, isEmpty);
  });

  test('closing balance ends the table so footer text is not appended', () {
    final result = parseIngStatement([
      ..._header(),
      ..._band(372.1, const [
        (70.8, '31.07.2026'),
        (141.6, 'Lastschrift'),
        (195.0, 'VISA'),
        (518.0, '-217,50'),
      ]),
      ..._band(400.0, const [
        (141.6, 'Neuer'),
        (170.0, 'Saldo'),
        (488.0, '2.927,04'),
      ]),
      ..._band(420.0, const [
        (141.6, 'Kunden-Information'),
      ]),
      ..._band(440.0, const [
        (69.0, 'ING-DiBa'),
        (94.0, 'AG'),
        (106.0, 'Theodor-Heuss-Allee'),
      ]),
    ]);

    expect(result.transactions.single.description, 'Lastschrift');
    expect(result.transactions.single.counterparty, 'VISA');
  });

  test('page furniture in the date column is skipped, not parsed', () {
    final result = parseIngStatement([
      ..._header(),
      ..._band(372.1, const [
        (70.8, '01.07.2026'),
        (141.6, 'Lastschrift'),
        (195.0, 'REWE'),
        (523.0, '-6,47'),
      ]),
      ..._band(600.0, const [
        (70.8, 'Girokonto'),
        (119.0, 'Nummer'),
        (162.0, '5457672768'),
      ]),
    ]);

    expect(result.transactions.single.description, 'Lastschrift');
    expect(result.warnings, isEmpty);
  });

  test('a page without a table header is reported, not silently dropped', () {
    final result = parseIngStatement(
      _band(372.1, const [
        (70.8, '01.07.2026'),
        (141.6, 'Lastschrift'),
        (518.0, '-126,00'),
      ]),
    );

    expect(result.transactions, isEmpty);
    expect(result.warnings.single, contains('Tabellenkopf nicht gefunden'));
  });

  test('each page uses its own header offset', () {
    final result = parseIngStatement([
      ..._header(),
      ..._band(372.1, const [
        (70.8, '01.07.2026'),
        (141.6, 'Lastschrift'),
        (195.0, 'REWE'),
        (523.0, '-6,47'),
      ]),
      ..._header(page: 1, top: 184.2),
      ..._band(215.5, const [
        (70.8, '02.07.2026'),
        (141.6, 'Lastschrift'),
        (195.0, 'Adyen'),
        (518.0, '-104,50'),
      ], page: 1),
    ]);

    expect(result.transactions.length, 2);
    expect(result.transactions.first.raw['page'], '1');
    expect(result.transactions.last.raw['page'], '2');
    expect(result.transactions.last.amountCents, -10450);
  });

  test('thousands separator and unsigned income parse correctly', () {
    final result = parseIngStatement([
      ..._header(),
      ..._band(372.1, const [
        (70.8, '06.07.2026'),
        (141.6, 'Gutschrift'),
        (195.0, 'STEUERVERWALTUNG'),
        (500.0, '2.974,48'),
      ]),
      ..._band(390.0, const [
        (70.8, '06.07.2026'),
        (141.6, 'Echtzeitüberweisung'),
        (250.0, 'Lukas'),
        (509.0, '-2.600,00'),
      ]),
    ]);

    expect(result.transactions.first.amountCents, 297448);
    expect(result.transactions.last.amountCents, -260000);
  });

  test('word text padded by the extractor is trimmed', () {
    final result = parseIngStatement([
      ..._band(216.7, const [
        (312.0, 'Neuer '),
        (342.0, ' Saldo'),
        (488.0, ' 2.927,04 '),
      ]),
      ..._header(),
      ..._band(372.1, const [
        (70.8, ' 01.07.2026 '),
        (141.6, 'Lastschrift '),
        (195.0, 'Belkaw '),
        (229.0, ' GmbH'),
        (518.0, ' -126,00'),
      ]),
    ]);

    expect(result.statementBalanceCents, 292704);
    expect(result.transactions.single.counterparty, 'Belkaw GmbH');
    expect(result.transactions.single.amountCents, -12600);
    expect(result.transactions.single.bookingDate, DateTime(2026, 7, 1));
  });

  test('a page whose header did not extract reuses the known columns', () {
    final result = parseIngStatement([
      ..._header(),
      ..._band(372.1, const [
        (70.8, '01.07.2026'),
        (141.6, 'Lastschrift'),
        (195.0, 'REWE'),
        (523.0, '-6,47'),
      ]),
      ..._band(215.5, const [
        (70.8, '02.07.2026'),
        (141.6, 'Lastschrift'),
        (195.0, 'Adyen'),
        (518.0, '-104,50'),
      ], page: 1),
    ]);

    expect(result.transactions.length, 2);
    expect(result.transactions.last.counterparty, 'Adyen');
    expect(result.warnings, isEmpty);
  });

  test('an appendix page with no table produces no warning', () {
    final result = parseIngStatement([
      ..._header(),
      ..._band(372.1, const [
        (70.8, '01.07.2026'),
        (141.6, 'Lastschrift'),
        (195.0, 'REWE'),
        (523.0, '-6,47'),
      ]),
      ..._band(200.0, const [
        (70.8, 'Bitte'),
        (95.0, 'beachten'),
        (140.0, 'Sie'),
        (160.0, 'die'),
        (180.0, 'Hinweise'),
      ], page: 10),
    ]);

    expect(result.transactions.length, 1);
    expect(result.warnings, isEmpty);
  });

  test('a date line with no booking in progress is warned about', () {
    final result = parseIngStatement([
      ..._header(),
      ..._band(372.1, const [
        (70.8, '01.07.2026'),
        (141.6, 'Wertstellung'),
      ]),
    ]);

    expect(result.transactions, isEmpty);
    expect(result.warnings.single, contains('ohne Buchung'));
  });
}
