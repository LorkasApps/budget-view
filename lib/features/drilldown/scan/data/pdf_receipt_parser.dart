import '../domain/receipt_line_item_parser.dart';
import 'receipt_pdf_words.dart';

/// Rows that carry an amount but are not positions: totals, taxes, savings,
/// deposit breakdowns and returned deposits. Matched on the block's lowercased
/// start, like the OCR parser's own list.
///
/// The deposit total (`Pfand`) is deliberately **not** here: it is money the user
/// paid, so it belongs in the booking. Its breakdown into bags and bottles is
/// what gets skipped.
const _skipPrefixes = {
  'summe',
  'zwischensumme',
  'gesamt',
  'total',
  'mwst',
  'ust',
  'netto',
  'brutto',
  'du sparst',
  'eingereichtes',
  'tüten',
  'flaschen',
  'lieferadresse',
  'kundenservice',
};

/// Skipped rows that state the document's own total. `zwischensumme` is absent on
/// purpose — a subtotal is not the figure to check against.
const _totalPrefixes = {'summe', 'gesamt', 'total'};

/// Rows that reduce what the user pays: returned deposits, refunds.
///
/// They cannot become positions — a `LineItem` amount is an unsigned magnitude
/// whose sign belongs to the parent booking (ticket 015) — but they must not be
/// ignored either: the printed total already accounts for them, so the checksum
/// only reconciles once they are subtracted.
const _creditPrefixes = {'eingereichtes', 'rückgabe', 'gutschrift', 'erstattung'};

/// A word that can be part of a price: digits, a separator, a currency mark.
///
/// Prices are **not** single words in a printed receipt. The observed shape is a
/// large integer, raised cents and a period, each its own word on its own
/// baseline — so the amount is reassembled from the digits of a band rather than
/// matched in one go.
final _priceFragment = RegExp(r'^[€]?[\d.,]+[€]?$');

final _digits = RegExp(r'^\d+$');

/// A leading count (`2x`, `3 Stk`) or measure (`250g`, `1,25L`).
final _quantityPrefix = RegExp(
  r'^(\d+(?:[.,]\d+)?)\s*(x|stk\.?|stück|kg|g|l|ml)\b\s*',
  caseSensitive: false,
);

const _countUnits = {'x', 'stk', 'stk.', 'stück'};

/// Fraction of the page width from which a money token counts as the price
/// column. Receipts and invoices right-align prices; anything further left is
/// part of the description, like a `jetzt 2.99€` promo note.
const double _priceColumnFraction = 0.6;

/// How far apart two words may sit vertically and still belong to one item,
/// expressed in median word heights. An item block spans description, unit and
/// price across roughly one and a half line heights; the gap to the next item is
/// several times that.
const double _blockToleranceInHeights = 1.6;

/// Reads a receipt or invoice out of a PDF's text layer.
///
/// Deliberately layout-driven rather than sender-specific: an item is a block of
/// words, its amount is the **bottom-most** money token in the price column — a
/// struck-through original sits above the price that replaced it — and the
/// document's own total is what says whether the reading can be trusted.
ReceiptParseResult parseReceiptPdf(List<ReceiptWord> words) {
  if (words.isEmpty) {
    return const ReceiptParseResult(candidates: []);
  }

  final tolerance = _blockTolerance(words);
  final priceColumnLeft = _priceColumnLeft(words, tolerance);

  // Two passes: the total bounds what a plausible position can be, and it is only
  // known once every block has been seen.
  final rows = [
    for (final block in _blocks(words, tolerance))
      _row(block, priceColumnLeft, tolerance),
  ];

  int? printedTotalCents;
  var creditCents = 0;
  for (final row in rows) {
    final lowered = row.label.toLowerCase();
    if (_totalPrefixes.any(lowered.startsWith)) {
      printedTotalCents = row.amountCents ?? printedTotalCents;
    } else if (_creditPrefixes.any(lowered.startsWith)) {
      creditCents += row.amountCents ?? 0;
    }
  }

  final candidates = <LineItemCandidate>[];
  for (final row in rows) {
    final amountCents = row.amountCents;
    // No amount, no item: address and legal blocks leave here.
    if (amountCents == null || row.label.isEmpty) continue;

    final lowered = row.label.toLowerCase();
    if (_totalPrefixes.any(lowered.startsWith)) continue;
    if (_creditPrefixes.any(lowered.startsWith)) continue;
    if (_skipPrefixes.any(lowered.startsWith)) continue;
    // Nothing on a receipt costs more than the receipt. Kills page furniture
    // whose digits happen to reassemble into an amount — a mail header, a
    // register number, a URL — without naming a single sender's vocabulary.
    if (printedTotalCents != null && amountCents > printedTotalCents) continue;

    candidates.add(_candidate(row, amountCents));
  }

  return ReceiptParseResult(
    candidates: candidates,
    printedTotalCents: printedTotalCents,
    creditCents: creditCents,
  );
}

/// Groups words into item blocks, page by page, top to bottom.
List<List<ReceiptWord>> _blocks(List<ReceiptWord> words, double tolerance) {
  final sorted = [...words]..sort((a, b) {
      final byPage = a.page.compareTo(b.page);
      return byPage != 0 ? byPage : a.centerY.compareTo(b.centerY);
    });

  final blocks = <List<ReceiptWord>>[];
  for (final word in sorted) {
    final current = blocks.isEmpty ? null : blocks.last;
    if (current != null &&
        current.last.page == word.page &&
        (word.centerY - current.last.centerY).abs() <= tolerance) {
      current.add(word);
    } else {
      blocks.add([word]);
    }
  }
  return blocks;
}

double _blockTolerance(List<ReceiptWord> words) {
  final heights = [for (final word in words) word.height]..sort();
  final median = heights[heights.length ~/ 2];
  return median * _blockToleranceInHeights;
}

/// Where the price column starts.
///
/// Taken from the leftmost price fragment in the right part of the page rather
/// than from a fixed fraction: a long product name can reach well past any
/// fraction one would pick, and losing its last word to the "price column" would
/// silently truncate the description.
double _priceColumnLeft(List<ReceiptWord> words, double tolerance) {
  var minLeft = words.first.left;
  var maxRight = words.first.right;
  for (final word in words) {
    if (word.left < minLeft) minLeft = word.left;
    if (word.right > maxRight) maxRight = word.right;
  }
  final fallback = minLeft + (maxRight - minLeft) * _priceColumnFraction;

  double? leftmostFragment;
  for (final word in words) {
    if (word.left < fallback) continue;
    if (!_priceFragment.hasMatch(word.text)) continue;
    if (leftmostFragment == null || word.left < leftmostFragment) {
      leftmostFragment = word.left;
    }
  }
  // Half a line of slack so the integer part of a price is never cut off.
  return leftmostFragment == null ? fallback : leftmostFragment - tolerance / 2;
}

/// Everything that is not part of a price, in reading order.
///
/// Membership is decided by shape, not only by x: a long product name reaches into
/// the price column, and dropping its last word would truncate the description
/// silently.
List<ReceiptWord> _labelWords(List<ReceiptWord> block, double priceColumnLeft) {
  return [
    for (final word in block)
      if (word.left < priceColumnLeft || !_priceFragment.hasMatch(word.text))
        word,
  ]..sort((a, b) {
      final byRow = a.centerY.compareTo(b.centerY);
      return byRow != 0 ? byRow : a.left.compareTo(b.left);
    });
}

/// Joins words back into text, gluing the ones a PDF split mid-word.
///
/// Syncfusion reports a break at every ligature and kerning pair, so `Röstkaffee`
/// arrives as `Röstkaf` + `fee`. Measured on a real receipt, such a break leaves a
/// gap of 0 while a real space is over 3, which is what makes the distinction
/// safe. It matters beyond looks: price trends group by normalised description, so
/// `Röstkaf fee` and `Röstkaffee` would be two different articles.
String _join(List<ReceiptWord> words, double tolerance) {
  if (words.isEmpty) return '';
  final glueBelow = tolerance / 8;

  final text = StringBuffer(words.first.text);
  for (var i = 1; i < words.length; i++) {
    final previous = words[i - 1];
    final word = words[i];
    final sameRow = (word.centerY - previous.centerY).abs() <= tolerance / 2;
    final gap = word.left - previous.right;
    text.write(sameRow && gap < glueBelow ? word.text : ' ${word.text}');
  }
  return text.toString().trim();
}

/// A lone number in its own column at the left edge of a block is the quantity.
///
/// Structural rather than textual: the gap to the description is many times a line
/// height, which is what tells a quantity column from the `1` of a `1 Stück` unit
/// sitting right next to its word.
({double? quantity, List<ReceiptWord> rest}) _splitQuantityColumn(
  List<ReceiptWord> words,
  double tolerance,
) {
  if (words.length < 2) return (quantity: null, rest: words);

  final byX = [...words]..sort((a, b) => a.left.compareTo(b.left));
  final first = byX.first;
  if (!RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(first.text)) {
    return (quantity: null, rest: words);
  }
  if (byX[1].left - first.right < tolerance * 2) {
    return (quantity: null, rest: words);
  }

  return (
    quantity: double.tryParse(first.text.replaceAll(',', '.')),
    rest: [
      for (final word in words)
        if (word != first) word,
    ],
  );
}

/// Amount of the block, in cents — reassembled from the price column and taken
/// from the **bottom-most** price band, because a struck-through original sits
/// above the price that replaced it.
int? _blockAmount(List<ReceiptWord> block, double priceColumnLeft) {
  final fragments = [
    for (final word in block)
      if (word.left >= priceColumnLeft && _priceFragment.hasMatch(word.text))
        word,
  ]..sort((a, b) => a.top.compareTo(b.top));
  if (fragments.isEmpty) return null;

  // A price's digits share a baseline; its period sits on its own, slightly
  // lower. One band is therefore "within a line height of the first fragment".
  final bands = <List<ReceiptWord>>[];
  for (final fragment in fragments) {
    final current = bands.isEmpty ? null : bands.last;
    if (current != null && fragment.top - current.first.top <= fragment.height) {
      current.add(fragment);
    } else {
      bands.add([fragment]);
    }
  }

  for (final band in bands.reversed) {
    final cents = _bandToCents(band);
    if (cents != null) return cents;
  }
  return null;
}

/// Digits of a band read left to right, with the last two taken as cents.
int? _bandToCents(List<ReceiptWord> band) {
  final ordered = [...band]..sort((a, b) => a.left.compareTo(b.left));
  final digits = ordered
      .map((word) => word.text.replaceAll(RegExp(r'[^0-9]'), ''))
      .where((text) => _digits.hasMatch(text))
      .join();
  if (digits.length < 3) return null;

  final cents = int.tryParse(digits);
  return cents == null || cents == 0 ? null : cents;
}

typedef _Row = ({
  String label,
  double? quantity,
  int? amountCents,
  String raw,
});

_Row _row(List<ReceiptWord> block, double priceColumnLeft, double tolerance) {
  final labelWords = _labelWords(block, priceColumnLeft);
  final split = _splitQuantityColumn(labelWords, tolerance);
  return (
    label: _join(split.rest, tolerance),
    quantity: split.quantity,
    amountCents: _blockAmount(block, priceColumnLeft),
    raw: _join(block, tolerance),
  );
}

LineItemCandidate _candidate(_Row row, int amountCents) {
  var description = row.label;
  var quantity = row.quantity;

  // No quantity column: fall back to a leading count or measure, the shape OCR
  // receipts use.
  if (quantity == null) {
    final prefix = _quantityPrefix.firstMatch(description);
    if (prefix != null) {
      quantity = double.tryParse(prefix.group(1)!.replaceAll(',', '.'));
      final unit = prefix.group(2)!.toLowerCase();
      // A count is consumed; a measure stays in the description, because
      // `LineItem` has no unit field (ticket 023).
      final measureStart = prefix.start + prefix.group(1)!.length;
      description = _countUnits.contains(unit)
          ? description.substring(prefix.end).trim()
          : description.substring(measureStart).trim();
    }
  }

  return LineItemCandidate(
    description: description,
    amountCents: amountCents,
    quantity: quantity,
    unitPriceCents: _unitPrice(amountCents, quantity),
    rawOcrText: row.raw,
  );
}

/// Only when the division lands within a cent — otherwise the UI's mismatch
/// warning is the honest answer, not an invented number.
int? _unitPrice(int amountCents, double? quantity) {
  if (quantity == null || quantity <= 0) return null;
  final derived = (amountCents / quantity).round();
  if (derived <= 0) return null;
  if (((derived * quantity).round() - amountCents).abs() > 1) return null;
  return derived;
}

