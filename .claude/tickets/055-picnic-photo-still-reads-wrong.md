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

## Device report after the summary-block fix (2026-08-25)
Scanned again on a debug build with the vocabulary fix in place. Still wrong, and the two symptoms together point somewhere
else entirely:

- **almost 2400 € recognised** where the receipt is about 62 €
- **every row reads `Ohne Beschreibung`** — that is `parseState == ambiguous`, an amount without any text

So the summary block was a real defect but not the dominant one. The next hypothesis, to be confirmed against the dump:

**The row grouping fails on this layout.** Each row of the Picnic app is tall because a product thumbnail sits on the left, so
the article name and its price are far apart vertically. The band tolerance is `(line height + row max height) / 4` — roughly
15 px for 30 px text, while name and price can sit 40 px apart. Then the price forms a band of its own (amount, no
description → `ambiguous`) and the name forms another (no money token → dropped into `unreadRows`). Both symptoms follow from
that one cause.

The inflated sum fits too: where no line carries a whole money token, 045's reassembly joins the digits of the price column's
bottom-most band. If such a band actually holds two different prices, the digits concatenate into something like `4791189` —
which is how a 62 € receipt reaches 2400 €.

If this holds, the answer is not a wider tolerance — 045 rejected that for regrouping every layout — but grouping that leans on
the **price column** rather than on text height. The dump decides. Not to be guessed: that is exactly how 045 produced a fix
that did not survive contact with a real photo.

**Next step, and the only one open:** the `OcrResult` dump of this receipt, fetched with the debug entry now in the app
(`adb exec-out run-as de.lorkaps_apps.budget_view cat <path> > /tmp/ocr_dump.json`).

## What the dump says (2026-09-07)
Dump taken on an emulator from the original 1080 × 6362 screenshot: 81 blocks, 91 lines, 71 blocks holding exactly one line.
Replaying the parser's own algorithm over it reproduces both reported symptoms, so the diagnosis no longer rests on a guess.

**Layout.** Three columns: quantity badge at x 26–58, article block at x 92–318, price right-aligned at x≈327.
`_priceColumnLeft` resolves to 268.

**The hypothesis holds in its core, and is wrong in its premise.**

- Confirmed: **no price line ever shares a band with its article name.** Of 22 price lines, 12 overlap nothing at all; the
  other 10 overlap only a sub-line — `Bündel-Bonus`, `30% Rabatt`, `2 x 125g`, `1ko`, `4 Stück`. The tolerance is
  `(line height + row max height) / 4` ≈ 8 px here, while the real gap between an article block's last line and its price is
  14–30 px. Replayed: 72 rows, **14 candidates summing to 37,71 €** against a printed 62,12 €, and **50 unread rows carrying
  every article name**. 11 of the 14 candidates have no description at all — the reported `Ohne Beschreibung`.
- Wrong premise: **there are no fragments to reassemble.** ML Kit returns each price as one token — `129`, `399`, `1060` —
  with the raised cents already merged, only without a separator. The assumption that `3` and `79` arrive on baselines 7 units
  apart does not describe this dump. `_priceBand` and `_bandToCents` then do the right thing by accident: `129` → 1,29.
- Also wrong: the inflation is not digit concatenation across a band. A promo row prints **both prices inside one line**,
  space-separated (`649 479`, `1196 1156`, `698 678`), and `_bandToCents` reads that as `119611,56 €`. Those rows are then
  dropped by `exceedsPositionBudget` — which is why the ~2400 € of 2026-08-25 no longer appears, and also why seven real
  articles vanish silently. The 24 € missing from the sum are exactly those.

**Reading the prices was never the defect.** Taking the rightmost token of each price line with the last two digits as cents
sums the column to 67,49 € against the printed `Betrag 67,07` — the difference being OCR misreads. The defect is pairing.

**Two further defects the dump exposes, independent of the grouping:**

1. **The skip vocabulary cannot match what OCR returns.** The labels come back misspelled: `Bestelung` (one `l` missing) and
   `Gespat` (the `r` missing). `_skipPrefixes` holds `bestellung` and `gespart`, so neither fires, and the replay shows
   `Gespat -5.73` **entering the positions as a 5,73 € item**. The AC claiming those three words are handled is ticked but does
   not hold on real data. `Bestelung 72.80` only escapes because 72,80 exceeds the budget, and `Betrag 67.07` only because it
   equals it — both by luck of a bound, not by the vocabulary.
2. **`_priceFragment` rejects a price with OCR noise in it.** Its charset is `[\d.,\s]`, so `3% 178` and `11:6 1060` are not
   fragments, their rows lose the price entirely and land in `unreadRows`.

Recorded so a later reader does not have to re-derive it: the replay was a throwaway Python mirror of the Dart, deliberately
not kept as a helper — a second implementation of parser logic drifts. The durable artifact is the fixture below.

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
