import 'package:flutter/foundation.dart';

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

/// Words on the same visual line differ in `top` by less than this — sub-pixel
/// noise, not a line break.
const _lineEpsilon = 1.0;

/// Groups words into visual rows: words whose `top` differs by less than
/// [tolerance] belong together. Bands run top to bottom, words inside a band in
/// reading order.
List<List<PositionedWord>> groupIntoBands(
  List<PositionedWord> words, {
  required double tolerance,
}) {
  final sorted = [...words]..sort((a, b) {
    final byTop = a.top.compareTo(b.top);
    return byTop != 0 ? byTop : a.left.compareTo(b.left);
  });

  final bands = <List<PositionedWord>>[];
  for (final word in sorted) {
    final isNewBand =
        bands.isEmpty || (word.top - bands.last.last.top).abs() > tolerance;
    if (isNewBand) {
      bands.add([word]);
    } else {
      bands.last.add(word);
    }
  }

  return [for (final band in bands) _readingOrder(band)];
}

/// A band wide enough to hold a wrapped cell carries more than one visual line —
/// a payee and the IBAN below it, a date split as `01 Juli` / `2026`. Sorting
/// such a band by `left` alone interleaves those lines, which scrambles every
/// text a parser joins out of it.
List<PositionedWord> _readingOrder(List<PositionedWord> band) {
  final lines = <List<PositionedWord>>[];
  for (final word in [...band]..sort((a, b) => a.top.compareTo(b.top))) {
    final isNewLine =
        lines.isEmpty || (word.top - lines.last.first.top).abs() > _lineEpsilon;
    if (isNewLine) {
      lines.add([word]);
    } else {
      lines.last.add(word);
    }
  }

  for (final line in lines) {
    line.sort((a, b) => a.left.compareTo(b.left));
  }
  return [for (final line in lines) ...line];
}
