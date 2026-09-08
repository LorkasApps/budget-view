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
  // A delivery receipt's summary block: `Bestellung` before discounts, `Gespart`
  // the discount total, `Betrag` after them, and `Rabatt` on the badge beside a
  // reduced item. None is an article, and all four carry a money token, so
  // without this they arrive as positions (ticket 055).
  'bestellung',
  'gespart',
  'betrag',
  'rabatt',
};

/// Shortest word whose misspelling the skip vocabulary will forgive. Below six
/// characters one edit turns a word into an unrelated one.
const _fuzzyMinLength = 6;

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

/// A line carrying no word: digits, separators and OCR noise only. ML Kit reads
/// a price column as `129`, `649 479`, `3% 178`, `11:6 1060` — a separator is
/// missing but there is nothing else on the line either.
final _priceOnly = RegExp(r'^[€\d.,:%\s-]+$');

final _digit = RegExp(r'\d');

final _nonDigit = RegExp(r'[^0-9]');

final _whitespace = RegExp(r'\s+');

/// A row after grouping: its full text for the vocabulary checks, the description
/// left once the price is taken out, and the price itself.
typedef _Row = ({String text, String label, int? amountCents});

/// Turns OCR text into candidate positions.
///
/// Layout does the heavy lifting: the prices are found first and each one
/// anchors a row, then every remaining line joins the price above which it
/// sits. Receipts right-align the price, and the ING parser derives its columns
/// from geometry the same way rather than trusting text patterns.
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
    final unreadRows = <String>[];
    for (final row in rows) {
      final amountCents = row.amountCents;
      // A row without an amount cannot be an item — address and header blocks
      // leave by this door rather than by keyword. It is kept as a diagnostic:
      // without it, a layout the parser cannot read looks like an empty receipt.
      if (amountCents == null) {
        unreadRows.add(row.text);
        continue;
      }
      if (statesReceiptTotal(row.text)) continue;
      if (statesReceiptCredit(row.text)) continue;
      if (_isSkippable(row.text)) continue;
      if (exceedsPositionBudget(amountCents, budget)) continue;

      candidates.add(_candidate(row, amountCents));
    }

    return ReceiptParseResult(
      candidates: dropTotalSizedRows(candidates, budget),
      printedTotalCents: printedTotalCents,
      creditCents: creditCents,
      unreadRows: unreadRows,
    );
  }

  /// Pairs every line of every block with a price. Blocks are ignored on
  /// purpose: ML Kit splits a receipt's description column and price column into
  /// separate blocks, which is exactly the pairing we are after.
  ///
  /// The price anchors the row, not the text: on a delivery receipt a product
  /// thumbnail pushes the article name 14 to 30 px above its price, while a
  /// tolerance read off the text height spans 8 px. Every line that is not a
  /// price goes to the first price at or below it, within one row pitch.
  /// Whatever finds no price stays a diagnostic instead of joining a row it does
  /// not belong to — that is what kept the page header out (ticket 055).
  List<_Row> _rows(OcrResult result) {
    final lines = [
      for (final block in result.blocks) ...block.lines,
    ]..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final anchors = _anchorIndexes(lines);
    final reach = _rowReach(lines, anchors);
    final grouped = [for (final _ in anchors) <OcrLine>[]];
    final unpaired = <OcrLine>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].text.trim().isEmpty) continue;
      final slot = _slotFor(lines, anchors, i, reach);
      if (slot == null) {
        unpaired.add(lines[i]);
      } else {
        grouped[slot].add(lines[i]);
      }
    }

    return [
      for (var i = 0; i < anchors.length; i++)
        _rowOf(grouped[i], lines[anchors[i]]),
      for (final line in unpaired)
        (text: line.text.trim(), label: '', amountCents: null),
    ];
  }

  /// The lines carrying a price, in document order. Where two prices share a
  /// band — a promotional row prints the struck-through original above the price
  /// that replaced it, both right-aligned — the bottom-most wins and the
  /// rightmost breaks a tie. Same rule as the PDF parser's bottom-most band, and
  /// the reason picking by x alone was a coin flip (ticket 043).
  List<int> _anchorIndexes(List<OcrLine> lines) {
    final indexes = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_anchorCents(lines[i].text) == null) continue;
      final box = lines[i].boundingBox;
      final previous = indexes.isEmpty
          ? null
          : lines[indexes.last].boundingBox;
      if (previous != null && box.top < previous.bottom) {
        final wins = box.bottom > previous.bottom ||
            (box.bottom == previous.bottom && box.right > previous.right);
        if (wins) indexes[indexes.length - 1] = i;
        continue;
      }
      indexes.add(i);
    }
    return indexes;
  }

  /// The price a line carries, or null when it carries none.
  ///
  /// The rightmost money token still wins, because that is where a receipt puts
  /// the price. When the line holds no token at all, and holds no word either,
  /// its rightmost group of digits is the price with the last two as cents: ML
  /// Kit returns a price as **one** token with the raised cents already merged
  /// but no separator, `129` for 1,29 (ticket 055 dump). Requiring the line to
  /// be wordless is what keeps `500g`, `2 x 125g` and `10er Pack` out.
  int? _anchorCents(String text) {
    final trimmed = text.trim();
    final tokens = _amountToken.allMatches(trimmed);
    if (tokens.isNotEmpty) {
      final match = tokens.last;
      return _toCents(match.group(1)!, match.group(2)!);
    }
    if (!_priceOnly.hasMatch(trimmed)) return null;

    final groups = trimmed.split(_whitespace);
    final index = groups.lastIndexWhere((group) => group.contains(_digit));
    if (index < 0) return null;
    final digits = groups[index].replaceAll(_nonDigit, '');
    // Two digits cannot be a price with cents, which is what keeps a quantity
    // badge — Picnic prints `1`, `2`, `3` in its own column — out.
    if (digits.length < 3) return null;

    final cents = int.tryParse(digits);
    return cents == 0 ? null : cents;
  }

  /// How far above its price a row may reach: the median distance between
  /// consecutive prices, derived per document. A receipt's row pitch is what
  /// separates one item from the next — the Picnic dump has a pitch of 87 px
  /// while its text is 7 to 17 px tall, so a tolerance taken from the text
  /// height cannot bridge the gap no matter how it is scaled (ticket 045 tried).
  double _rowReach(List<OcrLine> lines, List<int> anchors) {
    if (anchors.isEmpty) return 0;
    if (anchors.length == 1) {
      // One price says nothing about the pitch, so its own height has to do.
      return lines[anchors.single].boundingBox.height * 3;
    }
    final gaps = [
      for (var i = 1; i < anchors.length; i++)
        lines[anchors[i]].boundingBox.bottom -
            lines[anchors[i - 1]].boundingBox.bottom,
    ]..sort();
    return gaps[gaps.length ~/ 2];
  }

  /// The row a line belongs to: the first price whose bottom edge is at or below
  /// the line's centre, as long as it is within [reach].
  int? _slotFor(
    List<OcrLine> lines,
    List<int> anchors,
    int index,
    double reach,
  ) {
    final own = anchors.indexOf(index);
    if (own >= 0) return own;

    final centre = lines[index].boundingBox.center.dy;
    for (var slot = 0; slot < anchors.length; slot++) {
      final bottom = lines[anchors[slot]].boundingBox.bottom;
      if (bottom < centre) continue;
      return bottom - centre > reach ? null : slot;
    }
    return null;
  }

  /// Joins a row left to right and cuts its description out of it.
  ///
  /// Left first, then top: the label has to lead the row for the skip vocabulary
  /// to see it — on the real receipt the price of `Bestelung 72.80` starts one
  /// pixel higher than its label.
  _Row _rowOf(List<OcrLine> lines, OcrLine anchor) {
    final ordered = [...lines]..sort((a, b) {
      final byLeft = a.boundingBox.left.compareTo(b.boundingBox.left);
      return byLeft != 0
          ? byLeft
          : a.boundingBox.top.compareTo(b.boundingBox.top);
    });

    return (
      text: _join(ordered.map((line) => line.text)),
      // Of the price line only what stands before the price is description. A
      // line that is nothing but a price is no description either: that is the
      // struck-through original, which stays visible in `rawOcrText` only.
      label: _labelOf(
        ordered,
        (line) => line == anchor
            ? _withoutPrice(line.text)
            : _isOnlyPrice(line.text)
                ? ''
                : line.text,
      ),
      amountCents: _anchorCents(anchor.text),
    );
  }

  String _labelOf(List<OcrLine> ordered, String Function(OcrLine) textOf) =>
      _join(ordered.map(textOf));

  /// The price line without its price. A wordless line is nothing but the price,
  /// so nothing is left of it.
  String _withoutPrice(String text) {
    final match = _amountToken.allMatches(text);
    if (match.isEmpty) return '';
    return text.substring(0, match.last.start);
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

  /// The row start against the skip vocabulary, allowing one wrong character in
  /// a word of six or more. OCR returns the summary block of a delivery receipt
  /// misspelled — `Bestelung`, `Gespat` — and an exact list cannot be kept in
  /// step with however the next scan misreads it (ticket 055). The PDF parser
  /// keeps exact matching: a text layer has no noise to forgive.
  bool _isSkippable(String text) {
    final normalized = text.toLowerCase().trimLeft();
    if (_skipPrefixes.any(normalized.startsWith)) return true;

    final first = normalized.split(_whitespace).first;
    if (first.length < _fuzzyMinLength) return false;
    return _skipPrefixes.any(
      (prefix) =>
          prefix.length >= _fuzzyMinLength && _isOneEditApart(first, prefix),
    );
  }

  /// One missing, extra or wrong character apart — no more.
  bool _isOneEditApart(String word, String target) {
    if ((word.length - target.length).abs() > 1) return false;

    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < word.length && j < target.length) {
      if (word[i] == target[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (word.length >= target.length) i++;
      if (word.length <= target.length) j++;
    }
    return edits + (word.length - i) + (target.length - j) <= 1;
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
