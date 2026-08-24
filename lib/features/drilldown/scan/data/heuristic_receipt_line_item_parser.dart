import '../../../../core/money/money.dart';
import '../domain/ocr_service.dart';
import '../domain/receipt_line_item_parser.dart';
import '../domain/receipt_row_rules.dart';

/// Rows whose first word marks them as anything but a position: totals, taxes,
/// payment lines, receipt metadata. Matched on the normalized row start.
const _skipPrefixes = {
  'summe',
  'gesamt',
  'zwischensumme',
  'total',
  'bargeld',
  'girocard',
  'ec-karte',
  'mwst',
  'ust',
  'netto',
  'brutto',
  'gegeben',
  'zurück',
  'rückgeld',
  'saldo',
  'datum',
  'uhrzeit',
  'bon',
  'filiale',
  'kunden',
  'karte',
  'kasse',
  'beleg',
  'ec-cash',
  'eur',
};

/// A money token: `1,23`, `1.23`, `1234,56`, `1.234,56`, `1 234,56`, each with
/// an optional `€` / `EUR` on either side.
final _amountToken = RegExp(
  r'(?:€\s*)?(\d{1,3}(?:[.,\s]\d{3})+|\d+)[.,](\d{2})(?!\d)\s*(?:€|EUR)?',
  caseSensitive: false,
);

/// A leading count (`2x`, `3 Stk`) or measure (`1,5 kg`, `0.5 l`).
final _quantityPrefix = RegExp(
  r'^(\d+(?:[.,]\d+)?)\s*(x|stk\.?|stück|kg|g|l|ml)\b\s*',
  caseSensitive: false,
);

const _countUnits = {'x', 'stk', 'stk.', 'stück'};

/// A row after grouping: its full text for the vocabulary checks, the description
/// left once the price is taken out, and the price itself.
typedef _Row = ({String text, String label, int? amountCents});

/// Turns OCR text into candidate positions.
///
/// Layout does the heavy lifting: lines are grouped into rows by vertical
/// overlap, and the rightmost money token of a row is the price — receipts
/// right-align it, and the ING parser derives its columns the same way rather
/// than trusting text patterns.
class HeuristicReceiptLineItemParser implements ReceiptLineItemParser {
  const HeuristicReceiptLineItemParser();

  @override
  ReceiptParseResult parse(OcrResult result) {
    final rows = _rows(result);

    // Two passes, like the PDF parser: the printed total bounds what a plausible
    // position can cost, and it is only known once every row has been seen.
    int? printedTotalCents;
    var creditCents = 0;
    for (final row in rows) {
      if (statesReceiptTotal(row.text)) {
        // The last total wins: a receipt that prints one twice ends with the
        // figure that counts.
        printedTotalCents = row.amountCents ?? printedTotalCents;
      } else if (statesReceiptCredit(row.text)) {
        creditCents += row.amountCents ?? 0;
      }
    }

    final budget = positionBudgetCents(printedTotalCents, creditCents);
    final candidates = <LineItemCandidate>[];
    for (final row in rows) {
      final amountCents = row.amountCents;
      // A row without an amount cannot be an item — address and header blocks
      // leave by this door rather than by keyword.
      if (amountCents == null) continue;
      if (statesReceiptTotal(row.text)) continue;
      if (statesReceiptCredit(row.text)) continue;
      if (_isSkippable(row.text)) continue;
      if (exceedsPositionBudget(amountCents, budget)) continue;

      candidates.add(_candidate(row, amountCents));
    }

    return ReceiptParseResult(
      candidates: candidates,
      printedTotalCents: printedTotalCents,
      creditCents: creditCents,
    );
  }

  /// Groups every line of every block into visual rows, top to bottom, and
  /// joins each row left to right. Blocks are ignored on purpose: ML Kit often
  /// splits a receipt's description column and price column into separate
  /// blocks, which is exactly the pairing we are after.
  List<_Row> _rows(OcrResult result) {
    final lines = [
      for (final block in result.blocks) ...block.lines,
    ]..sort(
        (a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy),
      );

    final rows = <List<OcrLine>>[];
    for (final line in lines) {
      final current = rows.isEmpty ? null : rows.last;
      if (current != null && _belongsToRow(current, line)) {
        current.add(line);
      } else {
        rows.add([line]);
      }
    }

    return [
      for (final row in rows)
        if (_rowOf(row) case final parsed when parsed.text.isNotEmpty) parsed,
    ];
  }

  /// Splits a grouped row into its text, its description and its price.
  ///
  /// The price comes from the **bottom-most** line that carries a money token: a
  /// promotional row prints the struck-through original above the price that
  /// replaced it, both right-aligned, so picking by x would be a coin flip — and
  /// `List.sort` is not stable, which is what made the winner arbitrary. Same rule
  /// as the PDF parser's bottom-most band. Within one line the rightmost token
  /// still wins, because that is where a receipt puts the price.
  _Row _rowOf(List<OcrLine> lines) {
    OcrLine? priceLine;
    for (final line in lines) {
      if (_amountToken.firstMatch(line.text) == null) continue;
      final lower = line.boundingBox.center.dy;
      if (priceLine == null || lower > priceLine.boundingBox.center.dy) {
        priceLine = line;
      }
    }

    final match = priceLine == null
        ? null
        : _amountToken.allMatches(priceLine.text).lastOrNull;
    final cents = match == null
        ? null
        : _toCents(match.group(1)!, match.group(2)!);

    final pieces = [
      for (final line in lines)
        (
          left: line.boundingBox.left,
          // On the price line, only what stands before the price is description —
          // the same cut the single-line case has always made. A line that is
          // nothing but a price is no description either: that is the struck-through
          // original, which stays visible in `rawOcrText` and nowhere else.
          text: line == priceLine
              ? line.text.substring(0, match!.start)
              : _isOnlyPrice(line.text)
                  ? ''
                  : line.text,
        ),
    ]..sort((a, b) => a.left.compareTo(b.left));

    final ordered = [...lines]
      ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

    return (
      text: _join(ordered.map((line) => line.text)),
      label: _join(pieces.map((piece) => piece.text)),
      amountCents: cents == 0 ? null : cents,
    );
  }

  bool _isOnlyPrice(String text) {
    final trimmed = text.trim();
    final match = _amountToken.firstMatch(trimmed);
    return match != null && match.start == 0 && match.end == trimmed.length;
  }

  String _join(Iterable<String> parts) => parts
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' ');

  bool _belongsToRow(List<OcrLine> row, OcrLine line) {
    final centers = row.map((entry) => entry.boundingBox.center.dy);
    final rowCenter = centers.reduce((a, b) => a + b) / row.length;
    final rowHeight = row
        .map((entry) => entry.boundingBox.height)
        .reduce((a, b) => a > b ? a : b);
    final tolerance = (line.boundingBox.height + rowHeight) / 4;
    return (line.boundingBox.center.dy - rowCenter).abs() <= tolerance;
  }

  bool _isSkippable(String text) {
    final normalized = text.toLowerCase().trimLeft();
    return _skipPrefixes.any(normalized.startsWith);
  }

  LineItemCandidate _candidate(_Row row, int amountCents) {
    var description = row.label;
    double? quantity;
    final prefix = _quantityPrefix.firstMatch(description);
    if (prefix != null) {
      quantity = double.tryParse(prefix.group(1)!.replaceAll(',', '.'));
      final unit = prefix.group(2)!.toLowerCase();
      // A count is fully consumed; a measure keeps its unit, because
      // `LineItem` has no unit field and the description carries it.
      final measureStart = prefix.start + prefix.group(1)!.length;
      description = _countUnits.contains(unit)
          ? description.substring(prefix.end).trim()
          : description.substring(measureStart).trim();
    }

    if (description.isEmpty) {
      return LineItemCandidate(
        amountCents: amountCents,
        quantity: quantity,
        rawOcrText: row.text,
        parseState: LineItemParseState.ambiguous,
      );
    }

    return LineItemCandidate(
      description: description,
      amountCents: amountCents,
      quantity: quantity,
      unitPriceCents: _unitPrice(amountCents, quantity),
      rawOcrText: row.text,
    );
  }

  /// Only when the division lands within a cent. A mismatch is left to the
  /// UI's warning instead of being filled in with a number nobody printed.
  int? _unitPrice(int amountCents, double? quantity) {
    if (quantity == null || quantity <= 0) return null;
    final derived = (amountCents / quantity).round();
    if (derived <= 0) return null;
    if (((derived * quantity).round() - amountCents).abs() > 1) return null;
    return derived;
  }

  int? _toCents(String whole, String fraction) =>
      parseEurosToCents('${whole.replaceAll(RegExp(r'[.,\s]'), '')}.$fraction');
}
