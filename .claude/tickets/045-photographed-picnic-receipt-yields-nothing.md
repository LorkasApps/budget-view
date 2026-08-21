# A photographed Picnic receipt yields almost no positions

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Severity** | High |
| **Status** | Draft |

## Description
The same Picnic receipt that the PDF path reads to the cent produces almost nothing when photographed or screenshotted. The
PDF path was verified on the device the same evening and works; the photo path on the same document does not.

This is a different failure from ticket 043. That one is about **wrong** results — a struck-through price winning, credits
missing from the checksum. This one is about **no** results.

## Hypothesis (to confirm before fixing)
Picnic prints the cents **raised**: in the PDF, `3` and `79` sat on baselines 7 units apart. ML Kit will very likely put them
in separate lines too, and the OCR parser's row grouping — tolerance `(line height + row max height) / 4` — then keeps them
apart. After ticket 035 a row without a money token is **dropped entirely**, so both halves disappear: the row holding a bare
`3` is not a money token, and the description row never had one.

If that holds, this is a regression from 035 for any layout with raised cents, and it is worth stating plainly that the same
ticket removed the diagnostic: before 035 an unrecognised row appeared in the review screen as raw OCR text under "Nicht
erkannt", which is exactly what would show what ML Kit read. Keeping them behind a collapsed "N nicht erkannte Zeilen" line
was option two in that refinement and was declined.

## Repro Steps
1. Photograph or screenshot a Picnic receipt (raised cents in the price column)
2. Booking → Positionen → Bon scannen → Kamera or Galerie
3. Review screen shows almost no positions

## Expected vs Actual
- **Expected:** roughly what the PDF path produces from the same receipt — around 30 positions
- **Actual:** almost nothing; the count still has to be recorded (see open questions)

## Affected Envs
Verified on a release APK on the device, 2026-08-21.

## Workaround
Use the PDF of the same receipt, which works.

## Since When
The drop-rule since ticket 035 (2026-08-21). Whether the layout ever worked before that is unknown — no Picnic receipt had
been photographed until now, and 035's own findings came from a different shop's receipt.

## Open questions for refinement
- **How many positions did the review screen actually show** — zero with "Es wurde keine Position erkannt", or a handful?
  That number decides whether the drop rule is the whole story
- **How do we see what ML Kit read?** There is no harness for it: ML Kit has no test-VM binding, so the only place the raw
  text can surface is the app itself. Options: bring back unrecognised rows behind a collapsed line, or a debug-only dump
- **Reassemble prices across lines, as the PDF parser does?** It joins a band of fragments and reads the last two digits as
  cents. `OcrLine` carries a bounding box, so the same idea is possible — and it is the same convergence question 043 asks
- Or is the row tolerance the real culprit, and raised cents simply need a wider one? That would be a smaller change with a
  larger blast radius: every layout regroups
- Should a row without an amount be kept as non-savable after all, instead of dropped? It would restore the diagnostic at the
  cost of the noise 035 removed

## Acceptance Criteria
_Not refined yet — the hypothesis needs confirming first._

## Affected Tests
- `heuristic_receipt_line_item_parser_test.dart` — a fixture with the integer and the cents on separate lines is the
  regression test this ticket needs, and it can be written before the fix
- Device verification belongs in 036, on a release APK

## Fixtures Needed
No. Synthetic `OcrResult` fixtures with split price lines, built inline as the suite already does.

## Token Usage
_Filled after Done._
