# The OCR path misses the rules the PDF path learned

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Severity** | Medium |
| **Status** | Draft |

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

## Open questions for refinement
- **How much of the PDF parser should the OCR parser borrow?** The checksum comparison, the credit subtraction and the
  plausibility bound are layout-independent and could move into shared code. The bottom-most-price rule needs geometry the
  OCR rows have but the joined row string throws away
- Should the two parsers converge on one implementation over a shared "words with boxes" abstraction, given `OcrLine` and
  `ReceiptWord` both carry text plus a rectangle? That is the bigger, cleaner answer and a much larger change
- Which vocabulary is genuinely shared, and which stays per source?
- 036 will walk both paths on a device — does this ticket wait for those findings, or land before so 036 measures the fixed
  state?

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Affected Tests
- `heuristic_receipt_line_item_parser_test.dart` gains the borrowed rules
- `pdf_receipt_parser_test.dart` must stay green: whatever moves into shared code must not change the PDF behaviour

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
