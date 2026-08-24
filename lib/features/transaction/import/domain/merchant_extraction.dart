/// After the reference block: `1047390819119/PP.4163.PP/. Picnic GmbH, …`
final _afterReference = RegExp(r'/PP\.\d+\.PP/\.\s*([^,]*),');

/// A refund carries no reference block and starts straight with the merchant:
/// `. HomeVision, Ihr Einkauf bei …`
final _leadingDot = RegExp(r'^\.\s*([^,]*),');

/// The second spelling, at the end: `… Ihr Einkauf bei Picnic GmbH`, optionally
/// followed by `/ABBUCHUNG VOM PAYPAL-KONTO`.
final _purchaseAt = RegExp(r'Ihr Einkauf bei\s+([^/]*)');

final _whitespace = RegExp(r'\s');

/// Reads the merchant out of a collective payer's purpose text, or null when the
/// text names none.
///
/// Shaped after PayPal, the only collective payer that has shown up:
/// `<reference>/PP.4163.PP/. <merchant>, Ihr Einkauf bei <merchant>`. The
/// merchant therefore appears **twice**, and both spellings are read.
///
/// Why both: ING wraps the purpose text at a column boundary, mid-word. On real
/// statement lines the break lands in different places, so one spelling comes out
/// clean while the other does not — `. Picnic G mbH, … bei Picnic GmbH` on one row,
/// `. HomeVision, … bei HomeV ision` on the next. The candidate with the fewest
/// whitespace runs is the unbroken one.
///
/// That choice is load-bearing rather than cosmetic: `normalizeForMatching`
/// collapses runs of whitespace but keeps single spaces, so `picnic g mbh` and
/// `picnic gmbh` would be two different rule keys — the same merchant learning two
/// rules, which is the very problem this is meant to end.
String? extractMerchant(String description) {
  final candidates = [
    for (final pattern in [_afterReference, _leadingDot, _purchaseAt])
      if (pattern.firstMatch(description)?.group(1) case final String found)
        if (found.trim() case final trimmed when trimmed.isNotEmpty) trimmed,
  ];
  if (candidates.isEmpty) return null;

  // Deliberately not `sort`: Dart's sort is not stable, and on a tie the earlier
  // pattern — the one before the comma — should win.
  var best = candidates.first;
  for (final candidate in candidates.skip(1)) {
    if (_spaces(candidate) < _spaces(best)) best = candidate;
  }
  return best;
}

int _spaces(String value) => _whitespace.allMatches(value).length;
