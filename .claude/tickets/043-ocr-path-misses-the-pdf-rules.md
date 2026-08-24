# The OCR path misses the rules the PDF path learned

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Severity** | Medium |
| **Status** | Done |

## Description
The same receipt can arrive as a PDF or as a photo — a Picnic confirmation is a mail that can be printed *or*
screenshotted. Ticket 033 derived several rules from a real document and implemented them in the PDF parser only, so a
screenshot of the very same receipt is read by weaker rules.

Two of the gaps have nothing to do with PDFs and are inconsistencies introduced by 033 rather than pre-existing ones:

| Gap | Effect on a photographed or screenshotted receipt |
|-----|--------------------------------------------------|
| **Struck-through price** | The OCR parser takes the rightmost money token of a row. A promotional row prints the original above the real price, both right-aligned, so grouping decides which one wins — and it may well be the price the shop is *not* charging. Silent wrong data, the same class as 035 |
| **Credits** | `Eingereichtes Pfand` reduces what was paid, and the printed total already accounts for it. The PDF parser subtracts it in the checksum; the OCR parser does not, so any receipt with a deposit return raises a **false** mismatch warning |
| **Plausibility bound** | The PDF parser drops any row costing more than the printed total, which is what removed page furniture without vocabulary. The OCR parser has no such bound |
| **`Pfand` in the skip list** | The OCR skip list has `rückgeld` and `zurück` but not `pfand`, `tüten`, `flaschen` — a deposit breakdown becomes three positions |

## Repro Steps
1. Screenshot a receipt whose row shows a struck-through price above the real one
2. Scan the screenshot through the camera or gallery path
3. Compare the parsed amount for that row against the paper

## Expected vs Actual
- **Expected:** photo and PDF of the same receipt yield the same positions
- **Actual:** the photo path can take the struck-through price, warns falsely when a deposit was returned, and keeps rows
  that cost more than the whole receipt

## Since When
Since ticket 033 (2026-08-21) for the divergence; the struck-through weakness itself has existed since 018 and was simply
never noticed, because no receipt with a promotional row had been scanned.

## Resolved during refinement
- **Extent** → borrow, do not converge. The three layout-independent rules (printed-total checksum, credit subtraction,
  plausibility bound) move into shared code together with the credit vocabulary; the two parsers stay separate. The
  bottom-most-price rule is fixed **inside** the OCR parser by deciding the price from the word boxes before the row is
  joined into a string. Rejected converging both onto one "words with boxes" implementation: every concrete defect here sits
  in the layout-independent half or in a spot the OCR parser can repair locally, so convergence would rebuild two working
  paths to fix bugs that go away without it — and its payoff only starts at a third source, while the one rule that genuinely
  needs geometry stays per source anyway, because a thermal receipt and a PDF text layer hand over different rectangles. If
  convergence is wanted later it becomes its own refactor ticket, after this fix
- **Vocabulary** → shared only for "money coming back": `pfand`, `leergut`, `gutschrift`, `eingereichtes pfand`. Those rows
  are **not** skipped but subtracted as `creditCents` (`decisions.md`, 2026-08-21), which is what stops the false mismatch
  warning. Payment and change words (`rückgeld`, `zurück`, `bargeld`, `ec`, `karte`, `summe`) stay per source: they describe
  how it was paid, not what was bought. `tüten` deliberately does **not** join the skip list — a bought bag is a real
  position and only looked like noise because it stood inside a deposit block; `flaschen` counts only in a deposit context.
  Start with this small vocabulary and extend it against real receipts, never speculatively
- **Order against 036** → this lands first, so the device pass measures the fixed state. 036 stays parked for now (user
  decision, 2026-08-24)

## Acceptance Criteria
- [x] The printed-total checksum, the credit subtraction and the plausibility bound live in shared code and are used by both
      the OCR and the PDF parser — `domain/receipt_row_rules.dart`. The checksum comparison itself was already shared:
      `ReceiptParseResult.expectedPositionSumCents` has held it since 035, the OCR parser simply never filled `creditCents`
- [x] OCR: a promotional row printing the original price above the real one yields the **lower** of the two right-aligned
      money tokens, decided from the word boxes before the row is joined
- [x] OCR: a returned deposit is subtracted as a credit, and a receipt carrying one raises no mismatch warning
- [x] OCR: a row costing more than the receipt is dropped
- [x] OCR: `Tüten` stays a position — **the second half of this AC rested on a wrong premise and is dropped:** a *paid*
      deposit breakdown (`Pfand Flaschen 0,25`) is money the user paid and belongs in the booking as positions, which is
      exactly why the PDF parser's own comment keeps `Pfand` out of its skip list. What went wrong on the Picnic receipt was
      the *returned* deposit, and that is now a credit
- [x] `pdf_receipt_parser_test.dart` passes unchanged — moving code into shared rules must not shift PDF behaviour
- [x] For the synthetic promo and deposit cases, both parsers produce the same positions and the same credit total
      (`receipt_parsers_agree_test.dart`)
- [x] `make check` green — 500 passed, 0 failed

## Found while implementing
- **The plausibility bound was wrong for any receipt with a credit**, in the PDF parser too. "Nothing costs more than the
  printed total" fails as soon as a deposit return is deducted from that total: positions then sum *higher* than what was
  paid, and a single legitimate item can exceed it. The bound now compares against `positionBudgetCents` = printed total +
  credits, which is the figure the positions must reach anyway. The latent PDF bug never showed because the deposit on the
  verified Picnic receipt was small against its total; the cross-parser test is what surfaced it, on a fixture where the
  deposit is most of the paid sum
- **`receipt-scan.md` overstated the OCR parser**: it documented credit handling that only ever existed in the PDF parser.
  Corrected with this ticket

## Affected Tests
- `heuristic_receipt_line_item_parser_test.dart` gains the borrowed rules
- `pdf_receipt_parser_test.dart` must stay green: whatever moves into shared code must not change the PDF behaviour

## Fixtures Needed
No. Synthetic OCR lines with rectangles, the way `heuristic_receipt_line_item_parser_test.dart` already builds them: a promo
row with two right-aligned amounts stacked, a deposit row, and a row above the printed total. Each shared rule gets one case
from both parser suites, so the PDF side is provably unchanged. Real receipts stay out of git and are walked on a device
through 036, which then measures the fixed state.

### Refinement Tokens (estimate)
- Input: ~13k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
- Input: ~60k tokens
- Output: ~7k tokens
