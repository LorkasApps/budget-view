import '../../../../core/format/date_format.dart';
import 'parse_result.dart';
import 'positioned_word.dart';

/// Wider than one would expect for a row, and deliberately so: the date wraps as
/// `01 Juli` / `2026` and those two lines sit 3.8pt above and below the baseline
/// carrying type, description and amounts. Rows are 31.6pt apart, so pulling all
/// three into one band is safe and makes a row a single band.
const _bandTolerance = 5.0;
const _columnTolerance = 6.0;

/// Amount as the statement prints it: never signed — the direction comes from
/// the running balance beside it — and with the currency inside the same word,
/// which is how the text layer hands it over.
final _amountPattern = RegExp(r'^\d{1,3}(?:\.\d{3})*,\d{2}$');
final _currencySuffix = RegExp(r'\s*€$');
final _dayPattern = RegExp(r'^\d{1,2}$');
final _yearPattern = RegExp(r'^\d{4}$');
final _isinPattern = RegExp(r'\b[A-Z]{2}[A-Z0-9]{9}\d\b');
final _payeePattern = RegExp(r'for\s+(.+?)\s*\(');

/// Headings that follow the cash table and end it.
///
/// `TRANSAKTIONSÜBERSICHT` is the money-market sweep, and it is deliberately not
/// imported: those rows mirror the cash rows that triggered them — a 38,71 €
/// interest payment on the 1st comes back as a 38,71 € fund purchase on the 2nd
/// — so taking both would count the statement twice and break the balance
/// reconciliation. To import them anyway, read that table's own header
/// (`DATUM | ZAHLUNGSART | GELDMARKTFONDS | STÜCK | KURS PRO STÜCK | BETRAG`)
/// like this one and give up the reconciliation.
const _headingsAfterTable = {
  'BARMITTELÜBERSICHT',
  'TRANSAKTIONSÜBERSICHT',
  'HINWEISE',
};

/// Reads a Trade Republic cash statement from its positioned words.
///
/// The table is `DATUM | TYP | BESCHREIBUNG | ZAHLUNGSEINGANG |
/// ZAHLUNGSAUSGANG | SALDO`, and its column positions come from the header row
/// of each page rather than from constants, the same rule the ING parser
/// follows.
///
/// The direction of a row is taken from the running `SALDO` column, not from
/// which of the two amount columns the number sits in: those two headers stand
/// close together and their values are right-aligned, so an x-boundary between
/// them would be the most fragile part of the whole parse. The printed amount is
/// then checked against the balance step, and a row where the two disagree is
/// reported.
///
/// Row grammar:
/// - two or more amounts in a band start a row: the rightmost is the new
///   balance, the one before it the movement
/// - a band with description-column words but no amounts continues the current
///   row, which is how a wrapped payee line arrives
ParseResult parseTradeRepublicStatement(List<PositionedWord> words) {
  final warnings = <String>[];

  final byPage = <int, List<PositionedWord>>{};
  for (final word in words) {
    final text = word.text.trim();
    if (text.isEmpty) continue;
    byPage.putIfAbsent(word.page, () => <PositionedWord>[]).add(
      PositionedWord(
        page: word.page,
        left: word.left,
        top: word.top,
        text: text,
      ),
    );
  }

  final pages = byPage.keys.toList()..sort();
  final bandsPerPage = {
    for (final page in pages)
      page: groupIntoBands(byPage[page]!, tolerance: _bandTolerance),
  };

  if (!bandsPerPage.values.any((bands) => bands.any(_isTableHeader))) {
    warnings.add(
      'Tabellenkopf DATUM/TYP/BESCHREIBUNG/SALDO nicht gefunden — '
      'kein Trade-Republic-Kontoauszug?',
    );
    return ParseResult(transactions: const [], warnings: warnings);
  }

  final balances = _cashBalances(bandsPerPage.values);
  if (balances == null) {
    warnings.add(
      'Anfangs- und Endsaldo der Kontoübersicht nicht gefunden — ohne sie ist '
      'die Richtung einer Zeile nicht bestimmbar',
    );
    return ParseResult(transactions: const [], warnings: warnings);
  }

  final candidates = <ParsedTransactionCandidate>[];
  var runningCents = balances.openingCents;

  for (final page in pages) {
    final bands = bandsPerPage[page]!;
    final columns = _columns(bands);
    // A page without the cash-table header carries a different table (the sweep)
    // or nothing but legal text.
    if (columns == null) continue;

    runningCents = _readPage(
      page: page,
      bands: bands,
      columns: columns,
      runningCents: runningCents,
      candidates: candidates,
      warnings: warnings,
    );
  }

  final sum = candidates.fold<int>(0, (total, c) => total + c.amountCents);
  final expected = balances.closingCents - balances.openingCents;
  if (sum != expected) {
    warnings.add(
      'Summe der gelesenen Zeilen ($sum) passt nicht zu Endsaldo − '
      'Anfangssaldo ($expected) — Auszug wird nicht importiert',
    );
    return ParseResult(
      transactions: const [],
      statementBalanceCents: balances.closingCents,
      warnings: warnings,
    );
  }

  return ParseResult(
    transactions: candidates,
    statementBalanceCents: balances.closingCents,
    warnings: warnings,
  );
}

class _Columns {
  const _Columns(this.dateLeft, this.typeLeft, this.descriptionLeft);

  final double dateLeft;
  final double typeLeft;
  final double descriptionLeft;
}

class _Balances {
  const _Balances(this.openingCents, this.closingCents);

  final int openingCents;
  final int closingCents;
}

class _RowDraft {
  _RowDraft({
    required this.page,
    required this.bookingDate,
    required this.type,
    required this.amountCents,
    required this.balanceCents,
  });

  final int page;
  final DateTime bookingDate;
  final String type;
  final int amountCents;
  final int balanceCents;

  final List<String> descriptionParts = [];

  ParsedTransactionCandidate build() {
    final description = _tidy(descriptionParts.join(' '));
    return ParsedTransactionCandidate(
      bookingDate: bookingDate,
      amountCents: amountCents,
      description: description.isEmpty ? type : description,
      counterparty: _counterparty(description, type),
      raw: {
        'page': '${page + 1}',
        if (type.isNotEmpty) 'type': type,
        'balance': '$balanceCents',
      },
    );
  }
}

/// The instrument, the payee, or — when the row names neither — its type.
///
/// A dividend row prints no instrument name, only `Cash Dividend for ISIN
/// IE00077FRP95`, so the ISIN is what identifies the position. It has to be the
/// counterparty rather than description-only: the dedupe hash is built over
/// amount, date and normalized counterparty, so two positions paying the same
/// amount on the same day would otherwise collapse into a false duplicate. It
/// also gives the tagging loop one rule per position.
String? _counterparty(String description, String type) {
  final isin = _isinPattern.firstMatch(description);
  if (isin != null) return isin.group(0);

  final payee = _payeePattern.firstMatch(description);
  if (payee != null) return _tidy(payee.group(1)!);

  return type.isEmpty ? null : type;
}

/// `DATUM | TYP | BESCHREIBUNG | … | SALDO`. The two amount headers are not
/// used as boundaries — see the note on direction above.
bool _isTableHeader(List<PositionedWord> band) {
  final texts = band.map((word) => word.text).toSet();
  return texts.contains('DATUM') &&
      texts.contains('TYP') &&
      texts.contains('BESCHREIBUNG') &&
      texts.contains('SALDO');
}

_Columns? _columns(List<List<PositionedWord>> bands) {
  for (final band in bands) {
    if (!_isTableHeader(band)) continue;
    final date = band.firstWhere((word) => word.text == 'DATUM');
    final type = band.firstWhere((word) => word.text == 'TYP');
    final description = band.firstWhere(
      (word) => word.text == 'BESCHREIBUNG',
    );
    return _Columns(date.left, type.left, description.left);
  }
  return null;
}

/// Opening and closing balance from `KONTOÜBERSICHT`: the first band under its
/// header that carries at least two amounts. Taking the first and last amount of
/// that row keeps it working when a direction column is empty, which the header
/// positions would not.
_Balances? _cashBalances(Iterable<List<List<PositionedWord>>> pages) {
  for (final bands in pages) {
    var seenHeader = false;
    for (final band in bands) {
      final texts = band.map((word) => word.text).toSet();
      if (!seenHeader) {
        seenHeader =
            texts.contains('ANFANGSSALDO') && texts.contains('ENDSALDO');
        continue;
      }

      final amounts = band
          .map((word) => _toCents(word.text))
          .whereType<int>()
          .toList();
      if (amounts.length < 2) continue;
      return _Balances(amounts.first, amounts.last);
    }
  }
  return null;
}

int _readPage({
  required int page,
  required List<List<PositionedWord>> bands,
  required _Columns columns,
  required int runningCents,
  required List<ParsedTransactionCandidate> candidates,
  required List<String> warnings,
}) {
  var balance = runningCents;
  var inTable = false;
  _RowDraft? current;

  void flush() {
    final row = current;
    if (row != null) candidates.add(row.build());
    current = null;
  }

  for (final band in bands) {
    if (!inTable) {
      inTable = _isTableHeader(band);
      continue;
    }
    if (band.any((word) => _headingsAfterTable.contains(word.text))) break;

    final dateWords = <String>[];
    final typeWords = <String>[];
    final descriptionWords = <String>[];
    final amounts = <int>[];

    for (final word in band) {
      if (word.left < columns.dateLeft - _columnTolerance) {
        continue; // left of the table
      }
      if (word.left < columns.typeLeft - _columnTolerance) {
        dateWords.add(word.text);
      } else if (word.left < columns.descriptionLeft - _columnTolerance) {
        typeWords.add(word.text);
      } else {
        final cents = _toCents(word.text);
        if (cents != null) {
          amounts.add(cents);
        } else {
          descriptionWords.add(word.text);
        }
      }
    }

    if (amounts.length >= 2) {
      flush();
      final date = _parseDate(dateWords);
      final newBalance = amounts.last;
      final printed = amounts[amounts.length - 2];
      final movement = newBalance - balance;
      balance = newBalance;

      if (date == null) {
        warnings.add(
          'Seite ${page + 1}: Zeile ohne lesbares Datum — "${_textOf(band)}"',
        );
        continue;
      }
      if (movement.abs() != printed) {
        warnings.add(
          'Seite ${page + 1}: Betrag $printed passt nicht zur Saldoänderung '
          '${movement.abs()} — "${_textOf(band)}"',
        );
      }

      current = _RowDraft(
        page: page,
        bookingDate: date,
        type: typeWords.join(' '),
        amountCents: movement,
        balanceCents: newBalance,
      );
      if (descriptionWords.isNotEmpty) {
        current!.descriptionParts.add(descriptionWords.join(' '));
      }
      continue;
    }

    if (amounts.length == 1) {
      warnings.add(
        'Seite ${page + 1}: Zeile mit nur einem Betrag, Richtung unklar — '
        '"${_textOf(band)}"',
      );
      continue;
    }

    if (descriptionWords.isNotEmpty && current != null) {
      current!.descriptionParts.add(descriptionWords.join(' '));
    }
  }

  flush();
  return balance;
}

DateTime? _parseDate(List<String> tokens) {
  int? day;
  int? month;
  int? year;

  for (final token in tokens) {
    final asMonth = monthNamesDe.indexWhere(
      (name) => name.toLowerCase() == token.toLowerCase(),
    );
    if (asMonth != -1) {
      month = asMonth + 1;
    } else if (_yearPattern.hasMatch(token)) {
      year = int.parse(token);
    } else if (_dayPattern.hasMatch(token)) {
      day = int.parse(token);
    }
  }

  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

int? _toCents(String text) {
  final bare = text.replaceFirst(_currencySuffix, '');
  if (!_amountPattern.hasMatch(bare)) return null;
  return int.tryParse(bare.replaceAll('.', '').replaceAll(',', ''));
}

String _textOf(List<PositionedWord> band) =>
    band.map((word) => word.text).join(' ');

String _tidy(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
