import '../../../../core/money/money.dart';
import '../domain/ocr_service.dart';
import '../domain/receipt_line_item_parser.dart';

/// Rows whose first word marks them as anything but a position: totals, taxes,
/// payment lines, receipt metadata. Matched on the normalized row start.
const _skipPrefixes = {
  'summe',
  'zwischensumme',
  'total',
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

/// Turns OCR text into candidate positions.
///
/// Layout does the heavy lifting: lines are grouped into rows by vertical
/// overlap, and the rightmost money token of a row is the price — receipts
/// right-align it, and the ING parser derives its columns the same way rather
/// than trusting text patterns.
class HeuristicReceiptLineItemParser implements ReceiptLineItemParser {
  const HeuristicReceiptLineItemParser();

  @override
  List<LineItemCandidate> parse(OcrResult result) {
    final candidates = <LineItemCandidate>[];

    for (final row in _rows(result)) {
      final text = row.trim();
      if (text.isEmpty) continue;
      if (_isSkippable(text)) continue;
      candidates.add(_candidate(text));
    }

    return candidates;
  }

  /// Groups every line of every block into visual rows, top to bottom, and
  /// joins each row left to right. Blocks are ignored on purpose: ML Kit often
  /// splits a receipt's description column and price column into separate
  /// blocks, which is exactly the pairing we are after.
  List<String> _rows(OcrResult result) {
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
        (row..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left)))
            .map((line) => line.text.trim())
            .where((text) => text.isNotEmpty)
            .join(' '),
    ];
  }

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

  LineItemCandidate _candidate(String text) {
    final matches = _amountToken.allMatches(text).toList();
    if (matches.isEmpty) {
      return LineItemCandidate(
        rawOcrText: text,
        parseState: LineItemParseState.unparsed,
      );
    }

    final match = matches.last;
    final amountCents = _toCents(match.group(1)!, match.group(2)!);
    if (amountCents == null || amountCents == 0) {
      return LineItemCandidate(
        rawOcrText: text,
        parseState: LineItemParseState.unparsed,
      );
    }

    var description = text.substring(0, match.start).trim();
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
        rawOcrText: text,
        parseState: LineItemParseState.ambiguous,
      );
    }

    return LineItemCandidate(
      description: description,
      amountCents: amountCents,
      quantity: quantity,
      unitPriceCents: _unitPrice(amountCents, quantity),
      rawOcrText: text,
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
