/// Rules a receipt row obeys whatever it was read from — a photo through OCR or a
/// PDF's text layer.
///
/// Only the layout-independent half lives here. Skip vocabulary stays with each
/// parser: payment lines, metadata and page furniture are worded per source, while
/// "this row states the total" and "this row gives money back" mean the same thing
/// on both. Geometric rules stay per source too, because a thermal print and a text
/// layer hand over different rectangles.
library;

/// Rows stating the document's own total. `zwischensumme` is deliberately
/// absent — a subtotal is not the figure to check against, and `startsWith`
/// keeps it out.
const receiptTotalPrefixes = {'summe', 'gesamt', 'total'};

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

bool statesReceiptTotal(String label) =>
    _startsWithAny(label, receiptTotalPrefixes);

bool statesReceiptCredit(String label) =>
    _startsWithAny(label, receiptCreditPrefixes);

/// What the positions of a receipt have to add up to, or null when it printed no
/// total.
///
/// Not the printed total itself: a returned deposit is already deducted there, so
/// the positions sum higher than what was paid.
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

bool _startsWithAny(String label, Set<String> prefixes) {
  final normalized = label.toLowerCase().trimLeft();
  return prefixes.any(normalized.startsWith);
}
