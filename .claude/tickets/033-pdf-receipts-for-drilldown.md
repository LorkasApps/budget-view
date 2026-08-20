# PDF receipts as a drilldown source

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None (016–018 shipped the scan flow) |
| **Status** | Draft |

## Description
The receipt flow accepts a camera capture or a gallery image. But a growing share of receipts never exists on paper:
Amazon and similar send a PDF invoice. Those are line-item sources too, and today there is no way in — the drilldown
stays empty for exactly the purchases that arrive with the best structured data.

A digital PDF is the easier case, not the harder one: it carries a text layer, so `syncfusion_flutter_pdf` (already a
dependency, used by the statement import) can extract text directly and **OCR is not involved at all**. What has to be
answered is what happens to that text afterwards.

## Why this is not just "add a third source button"
The parser from ticket 018 was written against OCR output of German supermarket receipts: rightmost money token per line,
a skip list for the totals block, tolerance for split blocks. An Amazon invoice has none of that shape — item tables,
quantity and unit-price columns, descriptions wrapping over several lines, and a layout that changes per sender. The
picker entry is an afternoon; the parsing is the ticket.

There is a precedent for the shape of the answer: statement import solved the same problem with a `PdfParser` interface
plus a registry that ranks candidates by confidence (007, 008), starting with exactly one concrete parser.

## Open questions for refinement
- **Which parser handles the text?** Reuse the receipt heuristic from 018 (probably a poor fit), write one concrete
  sender-specific parser first (the `IngGiroParser` route), or introduce a receipt-parser registry with confidence
  ranking from the start?
- **How is the source modelled?** `ImportedSourceKind` is `pdf` | `photo` today, where `pdf` means "bank statement".
  A PDF receipt is format `pdf` but belongs to the scan path — does the enum gain a value, does it split into format and
  path, or does `photo` quietly become "receipt"? This decides what the import history shows
- **Scanned PDFs without a text layer:** refuse with a readable message, or fall back to the OCR path by rendering the
  page? The second sounds free but is not — nothing in the app renders PDF pages today
- **Multi-page invoices:** first page only, or all pages concatenated? Amazon puts one order per document, but shipping
  confirmations differ
- **Which booking does it attach to?** The photo flow starts from a booking and writes its line-items there. A PDF
  invoice arrives without that context — is it always started from a booking, or does it want to find its booking (amount
  and date matching against imported statement rows)?
- **Does the doc-hash check carry over unchanged?** It hashes bytes, so re-import warning should work as-is, but the
  message wording says "Bon" today
- Scope check: parser plus source-model change plus entry point may be more than one ticket

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Out of Scope (proposed, to confirm)
- Fetching invoices from a mailbox or a shop account — the user picks a file, nothing goes online
- Storing the PDF itself (project-wide decision: documents are never persisted)

## Affected Tests
Unknown until the parser question is answered. A digital PDF is a deterministic input, so unlike the OCR path this is
genuinely unit-testable — a committed sample would be the one exception to "no documents in git" and needs a decision.

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
