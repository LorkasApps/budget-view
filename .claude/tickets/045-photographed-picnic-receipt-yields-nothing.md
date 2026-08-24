# A photographed Picnic receipt yields almost no positions

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 043 (it owns the shared vocabulary this ticket changes the matching of) |
| **Severity** | High |
| **Status** | Ready |

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
- **Actual:** only the summary rows — `Bestellung`, `Betrag`, `Eingereichtes Pfand`, `Endsumme`. Not one item

## Evidence, recorded on the device 2026-08-21
The surviving rows are exactly the ones whose amount is rendered as a **single** token. Every item row, where the cents are
raised, is gone. That is the hypothesis above, confirmed: the item price splits across OCR lines, neither half is a money
token, and since 035 such a row is dropped.

Two further findings fall out of the same observation:

| Finding | Consequence |
|---------|-------------|
| `Endsumme` was read as a **position**, not as the total | Skip and total matching is on **prefix**. `Endsumme` contains `summe` but does not start with it, so the receipt's total went unrecognised — and without a total there is no checksum and no plausibility bound, so 043's fix could not help here either |
| `Eingereichtes Pfand` became a position | The credit handling exists only in the PDF parser (ticket 043). Here it makes the sum wrong on top of everything else |

German compounds put the keyword at the end more often than at the start: `Endsumme`, `Rechnungsbetrag`, `Kartenzahlung`. The
prefix rule was derived from one shop's receipts and does not generalise.

## Affected Envs
Verified on a release APK on the device, 2026-08-21.

## Workaround
Use the PDF of the same receipt, which works.

## Since When
The drop-rule since ticket 035 (2026-08-21). Whether the layout ever worked before that is unknown — no Picnic receipt had
been photographed until now, and 035's own findings came from a different shop's receipt.

## Resolved during refinement
- **The fix is reassembly, not a wider tolerance** → the price column gets its own, tighter join rule: fragments that overlap
  in x and sit close vertically are pulled together and the last two digits read as cents, exactly what the PDF parser does.
  Raised cents are a typographic fact, so the repair belongs where the geometry is. Widening the row tolerance would regroup
  **every** layout — the one thing 035 just tuned against real receipts — to fix a case that is locally solvable. Matches the
  cut made in 043: layout-independent rules are shared, geometric ones stay per source
- **Vocabulary matching** → a keyword hits when a token in the row **starts or ends with it** (case-insensitive). Prefix
  misses `Endsumme`; a whole-word rule misses it too, because `summe` is the second half of a compound, not a word of its own;
  a free substring would hit inside unrelated words. Starts-or-ends catches exactly the cases the evidence names —
  `Endsumme`, `Rechnungsbetrag`, `Kartenzahlung` as suffixes, `Summe` and `Betrag` as whole words. Accepted edge: a bought
  `Pfandflasche` starts with `pfand` and would read as a credit; to be corrected against real receipts, not pre-emptively
- **Diagnostic** → discarded rows return to the review screen behind a **collapsed** `N nicht erkannte Zeilen` line showing
  the raw OCR text. They do **not** become candidates again, so they stay out of the positions. A debug-only dump was
  rejected: this bug shows up on a release APK, where `kDebugMode` output does not exist (the lesson of 034) — a diagnostic
  missing from the broken build is no diagnostic. Collapsed by default keeps the noise 035 removed out of sight until asked
  for; that was option two in 035's refinement, declined then for lack of a reason, and the reason now exists
- **Order** → after 043, even though this is the more severe ticket. 043 owns the shared vocabulary whose matching rule this
  ticket changes, so landing first would mean doing that work twice; and the fix here is incomplete without 043 anyway,
  because a recognised `Endsumme` is what lets the checksum and the plausibility bound apply to this receipt at all

## Acceptance Criteria
- [ ] A synthetic `OcrResult` with `3` and `79` on separate lines in the price column yields **one** position of 379 cents
- [ ] The row tolerance for description rows is unchanged — no other layout regroups
- [ ] `Endsumme` is recognised as the receipt total, not as a position
- [ ] `Eingereichtes Pfand` is treated as a credit (the 043 rule) and is not a position
- [ ] With the total recognised, the checksum and the plausibility bound from 043 apply on this receipt
- [ ] The review screen shows a collapsed `N nicht erkannte Zeilen` line with the raw OCR text of every discarded row;
      expanding it changes nothing about the candidate list, and none of those rows can be saved
- [ ] The diagnostic line is collapsed on arrival and absent when nothing was discarded
- [ ] `make check` green

## Device check (belongs to 036, on a release APK)
- [ ] The photographed Picnic receipt yields roughly what the PDF path yields from the same document — around 30 positions
      instead of four summary rows

## Affected Tests
- `heuristic_receipt_line_item_parser_test.dart` — a fixture with the integer and the cents on separate lines is the
  regression test this ticket needs, and it can be written before the fix. Plus the vocabulary cases: `Endsumme` as total,
  `Eingereichtes Pfand` as credit
- The review-screen widget test gains the collapsed diagnostic: present with discarded rows, absent without, and expanding it
  leaves the candidate list untouched
- Device verification belongs in 036, on a release APK

## Fixtures Needed
No. Synthetic `OcrResult` fixtures with split price lines, built inline as the suite already does.

### Refinement Tokens (estimate)
- Input: ~16k tokens
- Output: ~2.5k tokens

### Implementation Tokens (estimate)
_Filled after Done._
