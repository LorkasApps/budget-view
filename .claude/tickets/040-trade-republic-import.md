# Trade Republic statement import

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Status** | Draft |

## Description
A second concrete parser behind the `PdfParser` seam from ticket 007, next to `IngGiroParser`. The registry already ranks
candidates by confidence and the flow already handles pick → parse → preview → persist, so the plumbing exists: this
ticket is the layout work plus one question the plumbing cannot answer.

Trade Republic PDFs carry a text layer, so `syncfusion_flutter_pdf` extracts them the same way the ING parser does. No
OCR, no new dependency.

## The question that decides the size of this ticket
Trade Republic issues two different documents, and only one of them is a bank statement:

| Document | Content | Fits today's model? |
|----------|---------|---------------------|
| Kontoauszug (cash) | deposits, card payments, transfers, interest | Yes — same shape as the ING statement |
| Wertpapierabrechnung / depot statement | buys, sells, savings-plan executions, dividends, fees | **No** — the app has no notion of securities |

A securities purchase is not spending: the money changes form, it does not leave. Booked as an expense it inflates the
report exactly the way ticket **032** describes for transfers between own accounts — same class of error, and probably the
same fix. A dividend, on the other hand, really is income. Fees really are spending.

So this ticket is small if it means the cash statement, and it is a milestone if it means the depot.

## Open questions for refinement
- **Which document first?** Cash statement only (a straight second parser), or is the depot the actual goal?
- If the depot: does a `Wertpapierkauf` become a transfer to an account of type depot (which would make this depend on
  032), or does the app grow a real notion of holdings — quantity, price per share, running position?
- Savings-plan executions repeat monthly with identical wording. Does dedupe hold, or do they look like duplicates of each
  other? The doc hash covers the file, the transaction hash covers amount plus date plus counterparty
- What is the counterparty on a securities line — the ISIN, the instrument name, the broker? The tagging rules key on
  normalized counterparty, so this decides what gets learned
- Does the statement's own closing balance exist to reconcile against, the way the ING parser checks
  `Neuer Saldo − Alter Saldo`? That check is what makes a parse trustworthy
- Which layouts are in scope — Trade Republic has changed its statement design more than once, and the registry ranks by
  confidence precisely so a stranger is refused rather than half-parsed
- Interest payments (`Zinsen`) on the cash balance: income, and worth a category by default?

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Out of Scope (proposed, to confirm)
- Live prices, portfolio valuation, performance — nothing that needs a network call
- Tax documents (Steuerreport) — a different document with a different purpose

## Affected Tests
- A concrete parser is unit-testable against extracted text, like `IngGiroParser` — but the reconciliation harness for
  real statements stays env-gated, since no statement enters the repo
- `pdf_parser_registry` tests gain a second parser: ranking, and the case where both parsers see a document

## Fixtures Needed
Ask during refinement. Note the project rule that no real statement is ever committed.

## Token Usage
_Filled after Done._
