/// Rules a receipt row obeys whatever it was read from — a photo through OCR or a
/// PDF's text layer.
///
/// Only the layout-independent half lives here. Skip vocabulary stays with each
/// parser: payment lines, metadata and page furniture are worded per source, while
/// "this row states the total" and "this row gives money back" mean the same thing
/// on both. Geometric rules stay per source too, because a thermal print and a text
/// layer hand over different rectangles.
library;

/// Rows stating the document's own total.
const receiptTotalPrefixes = {'summe', 'gesamt', 'total'};

/// A subtotal is not the figure to check against, and it has to be named: the
/// matching below looks at the end of a word too, so `zwischensumme` would
/// otherwise pass as a total.
const receiptSubtotalPrefixes = {'zwischensumme'};

/// Rows that reduce what the user paid: returned deposits, refunds.
///
/// They cannot become positions — a `LineItem` amount is an unsigned magnitude
/// whose sign belongs to the parent booking (ticket 015) — but they must not be
/// dropped either: the printed total already accounts for them, so the
/// positions reconcile only once these are subtracted.
const receiptCreditPrefixes = {
  'eingereichtes',
  'rückgabe',
  'gutschrift',
  'erstattung',
};

bool statesReceiptTotal(String label) {
  final words = _words(label);
  if (words.any((word) => _matchesAny(word, receiptSubtotalPrefixes))) {
    return false;
  }
  return words.any((word) => _matchesAny(word, receiptTotalPrefixes));
}

bool statesReceiptCredit(String label) =>
    _words(label).any((word) => _matchesAny(word, receiptCreditPrefixes));

/// What the positions of a receipt have to add up to, or null when it printed no
/// total.
///
/// Not the printed total itself: a returned deposit is already deducted there,
/// so the positions sum higher than what was paid.
int? positionBudgetCents(int? printedTotalCents, int creditCents) =>
    printedTotalCents == null ? null : printedTotalCents + creditCents;

/// Nothing on a receipt costs more than the whole receipt.
///
/// Bounds page furniture whose digits happen to reassemble into an amount — a
/// mail header, a register number, a URL — without naming a single sender's
/// vocabulary. Compared against [positionBudgetCents] rather than the printed
/// total, because on a receipt whose deposit return is large the printed total
/// falls below single legitimate items.
bool exceedsPositionBudget(int amountCents, int? budgetCents) =>
    budgetCents != null && amountCents > budgetCents;

List<String> _words(String label) => label
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .toList();

/// A keyword counts when a word **starts or ends** with it.
///
/// German puts the keyword at the end of a compound at least as often as at the
/// start: `Endsumme`, `Rechnungsbetrag`, `Kartenzahlung`. A prefix rule was read
/// off one shop's receipts and misses those; a free substring would hit inside
/// unrelated words. Known edge accepted: a bought `Pfandflasche` starts with
/// `pfand` and reads as a credit — to be corrected against real receipts.
bool _matchesAny(String word, Set<String> keywords) => keywords.any(
      (keyword) => word.startsWith(keyword) || word.endsWith(keyword),
    );
