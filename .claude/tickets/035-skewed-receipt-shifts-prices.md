# Receipt scan: prices shift on skew, and noise rows become positions

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Severity** | High |
| **Status** | Ready |

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

## Why the pairing shifts (confirmed against the docs)
`HeuristicReceiptLineItemParser` already groups geometrically: lines are sorted by vertical position and merged into one
row when their vertical centres lie within `(line height + row max height) / 4`. That tolerance is the breaking point.
Across half a receipt's width, a few degrees of skew move the right-hand price by more than a line height, so it joins the
neighbouring row — which is exactly the observed "item 2 with price 1" pattern. The grouping is not wrong in kind, it
assumes the rows are axis-parallel.

## Resolved during refinement
- **Approach** → deskew the bitmap **before** OCR rather than compensating the angle inside the grouping. Chosen over the
  cheaper box-regression variant because it also improves recognition itself, not only the pairing. Accepted cost: it runs
  ahead of every scan, including the straight ones, and it is more code than a rotation applied to coordinates.
  Consequence to keep in mind: the grouping tolerance stays as it is, so an under-corrected image reproduces the exact same
  silent shift — a safety net matters more with this route, not less
- **Angle source** → projection profile on the bitmap: for a set of candidate angles, sum the greyscale rows and take the
  angle with the sharpest structure. Chosen over deriving the angle from a first OCR pass, so recognition runs once.
  Accepted cost: real image processing with a candidate-angle raster, and its runtime depends on resolution and step width
  — the existing downscale before OCR is the place to hang it
- **Noise rows** → two changes. The skip vocabulary gains the prefixes this receipt exposed (`gesamtpreis`, `bargeld`, and
  whatever else the sample shows), and a row **without a money token never becomes a candidate** at all, which removes the
  address block by construction. Accepted cost: the docs call showing unrecognised rows a deliberate choice, and that hint
  ("there was text here I could not read") is given up
- **Checksum** → the printed total is read but still never imported: its amount is compared against the sum of the parsed
  positions, and a mismatch is shown in the review screen with both numbers. This is the only signal on a receipt that is
  independent of the row grouping, and it would have caught today's finding on its own. It stays quiet once the user
  deselects rows, since then a difference is intended
- **Fixtures** → no committed images. The angle test paints its own striped bitmap, rotates it by a known angle and asserts
  the estimate within a tolerance. It measures the angle estimation, not recognition quality

## Acceptance Criteria
- [ ] A deskew step runs between the existing downscale and the OCR call: projection-profile angle estimate over candidate
      angles, then rotation through `image`
- [ ] The candidate range and step live in one named place and are wide enough for a hand-held photo (starting point
      ±12° at 0.5°, adjust against real captures)
- [ ] An image that is already straight is **not** rotated — an estimate near zero skips the resampling instead of
      degrading the bitmap for nothing
- [ ] Unit test: a synthetic striped bitmap rotated by a known angle is estimated back within a stated tolerance, for
      several angles including 0
- [ ] The skip vocabulary gains the prefixes the sample receipt exposed, at least `gesamtpreis` and `bargeld`
- [ ] A row without a money token never becomes a `LineItemCandidate`, so address and header blocks disappear by
      construction rather than by keyword
- [ ] With that, `parseState.unparsed` is unreachable for value-less rows: either something else still produces it, or the
      state and its review rendering go — no branch kept for a case no input can reach (decisions.md)
- [ ] The printed total is parsed, never imported, and compared against the sum of the parsed positions
- [ ] A mismatch is shown in the review screen naming both numbers; deselecting rows silences it
- [ ] Tests: skip vocabulary, value-less rows dropped, checksum match and mismatch, and that the total row itself is not
      importable
- [ ] `make check` green
- [ ] Device verification is **not** part of this ticket — it lives in 036, which requires a release APK

## Out of Scope
- Perspective correction (a receipt photographed at an angle rather than rotated); only in-plane rotation is addressed
- Improving recognition itself beyond what a straightened image gives for free

## Affected Tests
The parser suites under `test/features/drilldown/scan/` are unit-testable with synthetic geometry: fixtures whose bounding
boxes are rotated by a few degrees would reproduce this without a device.

## Fixtures Needed
No committed fixtures. The angle test generates its own bitmaps; parser tests keep building `OcrResult` inline as the
existing suites do.

### Refinement Tokens (estimate)
- Input: ~20k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
_Filled after Done._
