# Trade Republic statement import

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 032 (transfers in and out of the Tagesgeld account) |
| **Status** | Ready |

## Description
A second concrete parser behind the `PdfParser` seam from ticket 007, next to `IngGiroParser`. The registry already ranks
candidates by confidence and the flow already handles pick → parse → preview → persist, so the plumbing exists: this
ticket is the layout work plus one question the plumbing cannot answer.

Trade Republic PDFs carry a text layer, so `syncfusion_flutter_pdf` extracts them the same way the ING parser does. No
OCR, no new dependency.

## Resolved during refinement
- **Scope** → the cash / Tagesgeld statement. That is the document that matters daily: deposits, withdrawals, interest and
  transfers. `AccountType.tagesgeld` already exists and `TransactionKind.transfer` from 032 covers the moves in and out, so
  no model change is needed — this is a second parser behind the existing contract
- **No securities model at all.** Holdings, quantities and prices are explicitly not of interest. A securities purchase is an
  **expense with a category**, a dividend and interest are **income with a category**. That removes the milestone-sized part
  of this ticket entirely, and it makes the tagging loop do the work: the instrument becomes a counterparty, so the second
  purchase of the same position is categorised automatically
- **Same for ING.** Securities charges appear as ordinary lines on the Giro statement, which `IngGiroParser` already reads as
  bookings. "It should hold for ING too" is therefore a confirmation, not a work package — worth verifying once against a
  real statement rather than assumed
- **Counterparty of a securities line** → the instrument name, with ISIN and details in the description. Readable in the rule
  list where rules are curated, one rule per position, and — decisive — the dedupe hash contains the normalized counterparty,
  so two different positions bought for the same amount on the same day stay distinguishable. A constant `Trade Republic`
  would have collapsed them into a false duplicate
- **Trust signal** → the balance reconciliation of the ING parser: read the old and new balance and check that the parsed rows
  sum to the difference. Same principle as the total validation in 033 and 035, and the only control the document carries
  itself. If Trade Republic does not print both balances, the check needs a replacement and this ticket says so rather than
  importing on faith
- **Test data** → an env-gated harness like `ing_geometry_dump_test.dart`; the user hands over a real statement out of band.
  Parser rules are covered by deterministic tests over synthetic text with coordinates. No document enters the repo

## Acceptance Criteria
- [ ] A `TradeRepublic…` parser is registered in the existing `PdfParserRegistry` and ranked by confidence next to
      `IngGiroParser`
- [ ] A real Trade Republic cash statement parses: row count and amounts match the document
- [ ] Old and new balance are read, and the parsed rows are verified to sum to their difference; a mismatch is reported
      instead of imported
- [ ] A statement of the wrong kind or an unknown layout is refused with a readable message, never half-parsed — same bar the
      device pass confirmed for foreign documents
- [ ] Securities lines become ordinary bookings: purchase as expense, dividend and interest as income
- [ ] Their counterparty is the instrument name; ISIN and remaining detail go into the description
- [ ] Monthly savings-plan executions of the same instrument do not collide in the dedupe check — same amount, same
      counterparty, different date must stay distinct bookings
- [ ] Transfers between the Giro account and the Tagesgeld account can be marked per 032; nothing in this ticket marks them
      automatically
- [ ] Unit tests over synthetic extracted text: row parsing, securities lines, interest, balance reconciliation match and
      mismatch, refusal of a foreign layout
- [ ] Env-gated harness parses a real statement from a path in an environment variable; no document is committed
- [ ] Verified once that securities charges on a real **ING** Giro statement already arrive as bookings, so the claim in the
      resolution holds
- [ ] `make check` green

## Out of Scope
- Live prices, portfolio valuation, performance — nothing that needs a network call
- Holdings: no quantity, no price per share, no running position
- Tax documents (Steuerreport) — a different document with a different purpose
- A separate ING depot document; securities appear on the Giro statement

## Affected Tests
- A concrete parser is unit-testable against extracted text, like `IngGiroParser` — but the reconciliation harness for
  real statements stays env-gated, since no statement enters the repo
- `pdf_parser_registry` tests gain a second parser: ranking, and the case where both parsers see a document

## Fixtures Needed
No committed documents. A real statement is handed over out of band and read by an env-gated harness.

### Refinement Tokens (estimate)
- Input: ~16k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
_Filled after Done._
