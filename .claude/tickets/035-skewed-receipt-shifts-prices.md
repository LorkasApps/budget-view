# Receipt scan: prices shift on skew, and noise rows become positions

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Severity** | High |
| **Status** | Draft |

## Description
Photographed slightly off-square, the receipt parses into plausible-looking positions with the prices shifted by one row:
item 2 got the price of item 1, item 3 the price of item 2, and so on. Nothing failed, nothing warned — the review screen
offered a tidy list that was wrong.

That is worse than a crash. The positions feed the drilldown, and from there the monthly report and the price trends, so
a shifted receipt quietly poisons the analytics it was captured for. A user cannot spot it either, unless they compare
every row against the paper — which is the work the scan was supposed to remove.

Found during the ticket 028 device pass, on a debug build (the release build cannot recognise anything at all — see 034).

## Repro Steps
1. Photograph a receipt with a few degrees of rotation / perspective, so lines are not horizontal
2. Open a booking → `Kassenbon scannen` → confirm the capture
3. Compare the review screen against the paper: descriptions are right, prices belong to the neighbouring row

## Expected vs Actual
- **Expected:** either each price sits on its own item, or the rows that cannot be paired confidently are marked
  `ambiguous` for the user to fix
- **Actual:** prices silently pair with the wrong description, with no marker

## Affected Envs
`dev` (debug build on device). Presumably every environment — the cause is geometric, not build-related.

## Workaround
Photograph the receipt square, or correct every position by hand in the review screen.

## Since When
Since the heuristic parser landed with ticket 018 (2026-08-17). No device pass had happened until now, and the unit tests
feed straight OCR fixtures, so skew never appeared.

## Second defect from the same scan: noise rows become positions
The same pass produced candidate rows for everything the receipt happens to print:

| Noise | Why it is not a position |
|-------|--------------------------|
| Shop address and header lines | No amount at all — a line without a money token cannot be an article |
| `Gesamtpreis` / total | It is the sum of the positions, so importing it double-counts the whole receipt |
| `Bargeld` given, `Rückgeld` | Payment, not purchase |
| EC / card terminal data | Terminal metadata |

All of them arrive as rows the user can only delete, one by one, on every single scan. Ticket 018 has a skip list for the
totals block, so either its patterns miss this shop's wording, or the rows are added before the list is consulted.

Note the two defects have different causes — geometry for the pairing, filtering for the noise — so refinement may well
split this ticket (the 013 → 025 and 009 → 024 splits are the precedent). They are filed together because they were found
in one scan and because the review screen is where both become visible.

Open questions for this half:
- Should a line **without** a money token ever become a candidate? Dropping those alone removes the address block
- Is the skip list keyword-based, and does it need this receipt's actual wording, or does it need a structural rule
  (everything below the total line is payment, not purchase)?
- The totals row is the one line whose value is known to be the sum — could it be used as a **check** instead of a row,
  comparing against the sum of parsed positions and flagging a mismatch?

## Why the pairing shifts (hypothesis to confirm during refinement)
The parser takes the rightmost money token of a line as that line's price. Once the paper is skewed, ML Kit's line
grouping no longer matches visual rows: a description and the price beside it drift into different lines, and the
right-hand column shifts against the left-hand one. The pairing rule assumes an axis-aligned layout that the photo does
not deliver.

## Open questions for refinement
- **Pair by geometry instead of by line membership?** Every `OcrLine` carries a bounding box. Pairing a price to the
  description whose vertical band it overlaps most would survive rotation up to some angle — what angle, and what happens
  beyond it?
- **Or deskew before OCR?** Estimating the dominant text angle and rotating the bitmap is a heavier, more general fix
  (`image` is already a dependency). It would also help the recognition rate itself, not just the pairing
- **Or refuse rather than guess?** Detect that lines are not parallel to the axis and ask for a straighter photo. Cheapest
  and honest, but pushes the work back to the user on every crooked shot
- **What must the review screen show either way?** Today a wrong pairing looks exactly like a right one. Marking
  low-confidence pairings `ambiguous` is arguably required regardless of which fix lands
- Does the same shift affect quantity and unit price when a receipt prints them in their own column?
- Accuracy needs numbers before and after: how many rows land `ok` / `ambiguous` / `unparsed` across several receipts,
  which is the measurement ticket 028 already asks for

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Affected Tests
The parser suites under `test/features/drilldown/scan/` are unit-testable with synthetic geometry: fixtures whose bounding
boxes are rotated by a few degrees would reproduce this without a device.

## Fixtures Needed
Likely yes — rotated-geometry OCR fixtures. Confirm during refinement.

## Token Usage
_Filled after Done._
