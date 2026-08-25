# A photographed Picnic receipt still reads almost nothing correctly

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Severity** | High |
| **Status** | In Progress |

## Description
Tickets 043 and 045 landed and `make check` is green, but a scan taken on the device after them still reads almost nothing
correctly. So the raised-cents reassembly, verified against synthetic coordinates, does not describe what ML Kit actually
returns for this receipt — or something else in the chain dominates the result.

This is the second time the same layout defeats the parser, and the first fix was built on assumed geometry. That is the thing
to change about *how* this one is fixed.

## Why the usual harness cannot help here
The PDF fixes were derived from a real document because `syncfusion_flutter_pdf` runs in the test VM. **ML Kit does not** — it
has no test-VM binding (`decisions.md`, 2026-08-17), which is exactly why no automated verification of real recognition
exists. A photo therefore cannot be pushed through a harness the way `ing_geometry_dump_test.dart` pushes a statement.

What can be done instead, and what this ticket proposes: **export the recognised layout from the app**. One dump of the real
`OcrResult` — blocks, lines, their `Rect`s — turns into a fixture with real coordinates, and from there the parser is testable
offline and deterministically, like every other layout rule in this project.

## Evidence in hand: the summary block is unaccounted for
A real screenshot of the receipt (Picnic app, 1080 × 6362) was read on 2026-08-25. Its summary block:

```
Bestellung            72,80
Gespart               -5,73
Betrag                67,07
Eingereichtes Pfand   -4,95
Endsumme              62,12
```

Of these the vocabulary knows two: `Endsumme` as the total (045) and `Eingereichtes Pfand` as a credit (043).
`Bestellung`, `Gespart` and `Betrag` are in no list, and that has consequences:

- **`Betrag 67,07` survives as a position.** It equals the position budget exactly (62,12 + 4,95), and the plausibility bound
  only drops rows costing *more* than the budget. So a row the size of the whole receipt enters the positions
- **`Gespart 5,73` survives as a position too** — the minus is not even read, the money pattern carries no sign
- **`Bestellung 72,80` is dropped**, because it exceeds the budget. By luck, not by design

Two invented positions, one of them as large as the entire purchase: enough for the sum warning to fire and for the review to
read as garbage. This is very plausibly the dominant cause, and it is a **vocabulary** gap rather than the geometry 045 fixed.

Also visible: a discounted item prints its struck-through original beside the real price together with a red `Rabatt` badge
carrying the discount amount. The badge is a third money token in that row and may become a position of its own.

These readings come from a downscaled view of the screenshot and are to be **confirmed against the `OcrResult` dump** — what
ML Kit makes of the block is what the parser actually sees.

## Evidence to collect before any fix
- [ ] The photo itself, handed over out of band (never committed — `decisions.md`, 2026-08-10: raw documents are not persisted)
- [ ] The dump of its `OcrResult` from the app
- [ ] What the review screen showed: how many positions, and what `N nicht erkannte Zeilen` contains when expanded
- [ ] Whether the sum warning fired, and with which two figures

## Resolved during refinement
- **The dump is a dev-only entry in the review screen** that writes the whole `OcrResult` — blocks, lines and their `Rect`s —
  as JSON into the app cache and shows the path, to be fetched with `adb pull` or a file app. It **stays**, but only in debug
  builds: at the next OCR surprise nobody should have to build it again.
  Rejected: a share intent (that is the same thing plus a path on which receipt text leaves the app, against the rule that raw
  documents are never kept), and a "copy all" on the existing `N nicht erkannte Zeilen` line — that yields text without
  rectangles, and assuming the geometry is exactly how 045 went wrong
- **The pattern is derived from that dump inside this ticket**, not before it, the way ticket 047 handled its purpose texts

## Acceptance Criteria
- [x] A debug-only action in the scan review writes the full `OcrResult` as JSON to the app cache and names the file; it is
      absent from a release build
- [ ] The dump of the failing Picnic photo is fetched, and the fixture in `heuristic_receipt_line_item_parser_test.dart` is
      built from its **real** coordinates
- [ ] That fixture reproduces the defect before the fix and passes after it
- [ ] For the real receipt: the positions the review offers match the paper — around 30 rows rather than four summary lines —
      and the printed total is recognised so the checksum can judge them
- [x] **No line of the summary block becomes a position**: `Bestellung`, `Gespart` and `Betrag` are handled, while `Endsumme`
      stays the total and `Eingereichtes Pfand` the credit
- [x] The plausibility bound drops a row that equals the budget as well, not only one that exceeds it — `Betrag` is exactly the
      budget, which is how it slipped through. `dropTotalSizedRows` keeps such a row when it is the **only** one, because a
      receipt with a single article legitimately equals its own total
- [x] A discounted row yields **one** position at the real price: neither the struck-through original nor the `Rabatt` badge
      becomes a row of its own
- [ ] Whatever the cause turns out to be, the finding is written into this ticket, including which of 045's synthetic
      assumptions was wrong
- [ ] The synthetic cases of 045 stay green, or their removal is argued in this ticket rather than done quietly
- [ ] `make check` green

## Device check
- [ ] The same photo, on a release APK, yields the same positions as the fixture predicts

## Affected Tests
- A fixture built from the real dump, in `heuristic_receipt_line_item_parser_test.dart`, is the regression test this ticket
  owes. The synthetic cases of 045 stay, but they clearly did not describe reality and must not be trusted as the only proof

## Fixtures Needed
No committed image. Real coordinates, transcribed from the dump into an inline fixture.

### Refinement Tokens (estimate)
- Input: ~9k tokens
- Output: ~1.5k tokens

### Implementation Tokens (estimate)
_Filled after Done._
