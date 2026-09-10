import 'package:budget_view/core/text/normalize.dart';

/// After the reference block: `1047390819119/PP.4163.PP/. Picnic GmbH, …`
final _afterReference = RegExp(r'/PP\.\d+\.PP/\.\s*([^,]*),');

/// A refund carries no reference block and starts straight with the merchant:
/// `. HomeVision, Ihr Einkauf bei …`
final _leadingDot = RegExp(r'^\.\s*([^,]*),');

/// The second spelling, at the end: `… Ihr Einkauf bei Picnic GmbH`, optionally
/// followed by `/ABBUCHUNG VOM PAYPAL-KONTO`.
final _purchaseAt = RegExp(r'Ihr Einkauf bei\s+([^/]*)');

final _whitespace = RegExp(r'\s');

/// Counterparties known to stand in front of the real shop and print it in the
/// card-terminal shape: `<merchant>/<street>/<city>/<country> <timestamp> …`.
///
/// A name list and not a shape rule, because an **ordinary** card payment prints
/// the same shape and there the counterparty already names the shop. Keying on the
/// shape would set a merchant there too and split one `kaufland` rule into one per
/// branch (ticket 050). The shape does not say that a counterparty is a proxy; only
/// the name does.
const _acquirers = {'adyen', 'nexi'};

/// `LS Akropolis Grill Loh/…` — a `Lastschrift` prefix on the merchant segment.
/// Stripped so the same shop does not key differently per printed prefix.
final _lastschriftPrefix = RegExp(r'^LS\s+');

/// Nexi appends a booking reference to the merchant segment:
/// `BAECKEREI SCHMIDT E K INHA 301 Refr GIR 79998979//…`. Assumed to vary per
/// booking, so it is cut off — a per-booking key would learn one rule per visit.
final _reference = RegExp(r'\bRefr\b');

/// Reads the merchant out of a collective payer's purpose text, or null when the
/// text names none — in which case the row keys on its counterparty.
///
/// Two payer shapes are known. PayPal is recognised by the marker in its own text
/// and needs no `counterparty`; the card acquirers are recognised by name, so
/// without a `counterparty` only the PayPal path can run.
String? extractMerchant(String description, {String? counterparty}) {
  final payPal = _fromPayPal(description);
  if (payPal != null) return payPal;
  if (counterparty == null) return null;
  final normalized = normalizeForMatching(counterparty);
  if (!_acquirers.any(normalized.startsWith)) return null;
  return _fromAcquirer(description);
}

/// The merchant is the leading segment before the first `/`, minus the prefix and
/// the trailing reference. The text layer drops characters and glues words, so the
/// result is occasionally incomplete (`Knigswinter`, `BootshausRadolfzell`) — it
/// stays a stable key regardless, which is all tagging needs.
String? _fromAcquirer(String description) {
  final segment = description.split('/').first;
  final merchant = segment
      .split(_reference)
      .first
      .replaceFirst(_lastschriftPrefix, '')
      .trim();
  return merchant.isEmpty ? null : merchant;
}

/// PayPal's shape: `<reference>/PP.4163.PP/. <merchant>, Ihr Einkauf bei <merchant>`.
/// The merchant appears **twice**, and both spellings are read.
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
String? _fromPayPal(String description) {
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
