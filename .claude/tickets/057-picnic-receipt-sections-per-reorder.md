# A Picnic receipt splits into sections when the order was added to

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Status** | Draft |

## Description
A Picnic order can be added to after it was placed. The receipt then carries a heading `Hinzugefügt am <dd MMMM>` above the
items that came later — and each of those parts is charged separately, so one PDF describes **several** bookings.

Today the parser reads the document as one receipt. Attaching it to a booking therefore imports items the booking never paid
for, the printed-total check compares against the wrong figure, and the Restposten absorbs a difference that is not a rounding
error but a whole second delivery.

The heading is the signal: it says which part of the receipt belongs to which charge.

## What this needs before code
No receipt with such a section has been read yet. The layout has to be dumped first — the same rule that turned up three wrong
assumptions in ticket 040 and one in 043. Specifically unknown:

- whether each section prints **its own total**, or only the document does
- whether the first section carries a heading too, or only the added ones
- what the date format really is (`13 Januar`, `13. Januar`, with or without a year) — `monthNamesDe` is public since ticket
  047 and would read it, if the shape matches
- whether the same heading appears in a **photographed** receipt, which would make this an OCR question as well as a PDF one

## Open questions for refinement
- **How is a section matched to the booking being scanned?** By date against `bookingDate`, or by the section's own total
  against the booking's amount? The total is the stronger signal and this project already trusts printed totals over
  vocabulary — but only if sections print one
- What happens when nothing matches: refuse, import everything as today, or let the user pick the section?
- What happens when **two** sections match — same date, two charges?
- Does the checksum then run per section? The plausibility bound (043) compares against the printed total plus credits; with
  sections that figure becomes per-section, and the current code knows one total per document
- Does `Weiteren Bon scannen` (016) become the natural path for the second section — same document, next booking — or does one
  pass offer to attach several sections to several bookings at once? The second is a different flow than anything that exists
- Is a section without items possible, and does an empty section warn or vanish?

## Acceptance Criteria
_Not refined yet — the dump comes first._

## Out of Scope (proposed, to confirm)
- Matching a receipt to a booking automatically across the whole account; the flow starts from a booking and stays there
- Other shops' multi-part receipts until one appears

## Affected Tests
- `pdf_receipt_parser_test.dart` gains section fixtures built from the real dump; the single-section case must read exactly as
  today
- The scan flow tests if the section choice reaches the controller

## Fixtures Needed
No committed document. A real Picnic receipt with a `Hinzugefügt am` section, handed over out of band, transcribed into inline
fixtures.

## Token Usage
_Filled after Done._
