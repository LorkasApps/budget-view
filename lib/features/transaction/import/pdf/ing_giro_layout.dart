import 'package:flutter/foundation.dart';

import 'parse_result.dart';

/// A word from a PDF text layer together with its position on the page.
@immutable
class PositionedWord {
  const PositionedWord({
    required this.page,
    required this.left,
    required this.top,
    required this.text,
  });

  final int page;
  final double left;
  final double top;
  final String text;
}

/// Words on the same visual row differ in `top` by less than this. Statement
/// rows sit ~12pt apart, so the margin is generous.
const _bandTolerance = 3.0;

/// Slack when deciding which column a word belongs to.
const _columnTolerance = 6.0;

final _datePattern = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$');

/// German amount, e.g. `-1.234,56` or `8,00`. No sign means income.
final _amountPattern = RegExp(r'^-?\d{1,3}(?:\.\d{3})*,\d{2}$');

/// Reads an ING Girokonto statement from its positioned words.
///
/// The statement is a three-column table (Buchung/Valuta, Verwendungszweck,
/// Betrag). Column boundaries are taken from each page's own header row rather
/// than hard-coded, so ING layout shifts do not silently break parsing.
///
/// Row grammar, deliberately independent of the booking-type vocabulary:
/// date + amount starts a row, a bare date is that row's Valuta, anything
/// starting in the description column continues it, and a non-date in the date
/// column marks page furniture to skip.
ParseResult parseIngStatement(List<PositionedWord> words) {
  final candidates = <ParsedTransactionCandidate>[];
  final warnings = <String>[];
  int? statementBalanceCents;

  // Extractors pad word text with surrounding spaces; untrimmed text breaks
  // both the label lookups and every join.
  final pages = <int, List<PositionedWord>>{};
  for (final word in words) {
    final text = word.text.trim();
    if (text.isEmpty) continue;
    pages.putIfAbsent(word.page, () => <PositionedWord>[]).add(
          PositionedWord(
            page: word.page,
            left: word.left,
            top: word.top,
            text: text,
          ),
        );
  }

  // Column positions repeat on every page, so a page whose header did not
  // extract can still be read with the previous page's geometry. A page with no
  // known columns at all is an appendix page (legal notes), not a table.
  _Columns? columns;

  for (final page in pages.keys.toList()..sort()) {
    final bands = _bands(pages[page]!);
    statementBalanceCents ??= _newBalance(bands);

    final pageColumns = _columns(bands);
    columns = pageColumns ?? columns;
    if (columns == null) continue;

    _readPage(
      page,
      bands,
      columns,
      candidates,
      warnings,
      // With a header on the page the table starts below it. Without one the
      // page continues a table whose header we already saw, so start reading
      // right away — page 1 is the only page carrying a pre-table header block.
      startInTable: pageColumns == null,
    );
  }

  if (columns == null) {
    warnings.add('Tabellenkopf nicht gefunden — kein ING-Girokonto-Auszug?');
  }

  return ParseResult(
    transactions: candidates,
    statementBalanceCents: statementBalanceCents,
    warnings: warnings,
  );
}

class _Columns {
  const _Columns(this.dateLeft, this.descriptionLeft, this.amountLeft);

  final double dateLeft;
  final double descriptionLeft;
  final double amountLeft;
}

class _Row {
  _Row({
    required this.page,
    required this.bookingDate,
    required this.type,
    required this.counterparty,
    required this.amountCents,
  });

  final int page;
  final DateTime bookingDate;
  final String type;
  final String counterparty;
  final int amountCents;

  DateTime? valueDate;
  final List<String> descriptionParts = [];
  String mandate = '';
  String reference = '';

  ParsedTransactionCandidate build() {
    final description = _tidy(descriptionParts.join(' '));
    final payee = _tidy(counterparty);
    return ParsedTransactionCandidate(
      bookingDate: bookingDate,
      valueDate: valueDate,
      amountCents: amountCents,
      description: description.isEmpty ? type : description,
      counterparty: payee.isEmpty ? null : payee,
      raw: {
        'page': '${page + 1}',
        if (type.isNotEmpty) 'type': type,
        if (mandate.isNotEmpty) 'mandate': mandate,
        if (reference.isNotEmpty) 'reference': reference,
      },
    );
  }
}

List<List<PositionedWord>> _bands(List<PositionedWord> words) {
  final sorted = [...words]..sort((a, b) {
    final byTop = a.top.compareTo(b.top);
    return byTop != 0 ? byTop : a.left.compareTo(b.left);
  });

  final bands = <List<PositionedWord>>[];
  for (final word in sorted) {
    final isNewBand = bands.isEmpty ||
        (word.top - bands.last.last.top).abs() > _bandTolerance;
    if (isNewBand) {
      bands.add([word]);
    } else {
      bands.last.add(word);
    }
  }

  for (final band in bands) {
    band.sort((a, b) => a.left.compareTo(b.left));
  }
  return bands;
}

/// Column positions from the header row `Buchung | Buchung / Verwendungszweck |
/// Betrag`. Matches the bare word `Betrag` because the extractor drops the
/// parentheses of `Betrag (EUR)`.
_Columns? _columns(List<List<PositionedWord>> bands) {
  for (final band in bands) {
    final labels = band.where((word) => word.text == 'Buchung').toList();
    final amount = band.where((word) => word.text == 'Betrag').toList();
    if (labels.length < 2 || amount.isEmpty) continue;
    return _Columns(labels.first.left, labels[1].left, amount.first.left);
  }
  return null;
}

int? _newBalance(List<List<PositionedWord>> bands) {
  for (final band in bands) {
    final texts = band.map((word) => word.text).toList();
    final label = texts.indexOf('Neuer');
    if (label == -1 || label + 1 >= texts.length) continue;
    if (texts[label + 1] != 'Saldo') continue;

    for (final word in band.skip(label + 2)) {
      final cents = _toCents(word.text);
      if (cents != null) return cents;
    }
  }
  return null;
}

void _readPage(
  int page,
  List<List<PositionedWord>> bands,
  _Columns columns,
  List<ParsedTransactionCandidate> candidates,
  List<String> warnings, {
  required bool startInTable,
}) {
  _Row? current;
  var inTable = startInTable;

  void flush() {
    final row = current;
    if (row != null) candidates.add(row.build());
    current = null;
  }

  for (final band in bands) {
    final dateWords = <PositionedWord>[];
    final descriptionWords = <PositionedWord>[];
    final amountWords = <PositionedWord>[];

    for (final word in band) {
      if (word.left < columns.dateLeft - _columnTolerance) {
        continue; // left of the table: the vertical document marker
      }
      if (word.left < columns.descriptionLeft - _columnTolerance) {
        dateWords.add(word);
      } else if (word.left < columns.amountLeft - _columnTolerance) {
        descriptionWords.add(word);
      } else {
        amountWords.add(word);
      }
    }

    if (!inTable) {
      inTable = descriptionWords.any((w) => w.text == 'Verwendungszweck');
      continue;
    }

    // The closing balance ends the table; trailing legal text must not be
    // appended to the last booking.
    if (_isClosingBalance(band)) break;

    final date = _firstDate(dateWords);
    if (dateWords.isNotEmpty && date == null) continue; // page furniture
    final amount = _firstAmount(amountWords);

    if (date != null && amount != null) {
      flush();
      current = _Row(
        page: page,
        bookingDate: date,
        type: descriptionWords.isEmpty ? '' : descriptionWords.first.text,
        counterparty:
            descriptionWords.skip(1).map((word) => word.text).join(' '),
        amountCents: amount,
      );
      continue;
    }

    final row = current;
    if (row == null) {
      if (date != null) {
        warnings.add(
          'Seite ${page + 1}: Datumszeile ohne Buchung — "${_textOf(band)}"',
        );
      }
      continue;
    }

    if (date != null) {
      if (row.valueDate == null) {
        row.valueDate = date;
      } else {
        warnings.add(
          'Seite ${page + 1}: unerwartete Datumszeile — "${_textOf(band)}"',
        );
      }
    }

    _appendDescription(row, descriptionWords);
  }

  flush();
}

bool _isClosingBalance(List<PositionedWord> band) {
  final texts = band.map((word) => word.text).toList();
  final label = texts.indexOf('Neuer');
  return label != -1 &&
      label + 1 < texts.length &&
      texts[label + 1] == 'Saldo';
}

void _appendDescription(_Row row, List<PositionedWord> words) {
  if (words.isEmpty) return;

  final texts = words.map((word) => word.text).toList();
  final rest = texts.skip(1).join(' ');
  if (texts.first == 'Mandat:') {
    row.mandate = rest;
  } else if (texts.first == 'Referenz:') {
    row.reference = rest;
  } else {
    row.descriptionParts.add(texts.join(' '));
  }
}

DateTime? _firstDate(List<PositionedWord> words) {
  for (final word in words) {
    final match = _datePattern.firstMatch(word.text);
    if (match == null) continue;
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }
  return null;
}

int? _firstAmount(List<PositionedWord> words) {
  for (final word in words) {
    final cents = _toCents(word.text);
    if (cents != null) return cents;
  }
  return null;
}

int? _toCents(String text) {
  if (!_amountPattern.hasMatch(text)) return null;
  return int.tryParse(text.replaceAll('.', '').replaceAll(',', ''));
}

String _textOf(List<PositionedWord> band) =>
    band.map((word) => word.text).join(' ');

String _tidy(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
