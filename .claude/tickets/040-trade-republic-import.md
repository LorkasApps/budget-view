# Trade Republic statement import

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 032 (transfers in and out of the Tagesgeld account) |
| **Status** | In Progress |

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
- [x] A `TradeRepublic…` parser is registered in the existing `PdfParserRegistry` and ranked by confidence next to
      `IngGiroParser`
- [x] A real Trade Republic cash statement parses: row count and amounts match the document
- [x] Old and new balance are read, and the parsed rows are verified to sum to their difference; a mismatch is reported
      instead of imported
- [x] A statement of the wrong kind or an unknown layout is refused with a readable message, never half-parsed — same bar the
      device pass confirmed for foreign documents
- [x] Securities lines become ordinary bookings: purchase as expense, dividend and interest as income — dividends and
      interest are confirmed against the real statement; a **purchase** does not occur on a TR cash statement at all (see
      the scope correction below), so that half rides on the ING cross-check
- [x] Their counterparty is the instrument name; ISIN and remaining detail go into the description — the document prints no
      instrument name, only `Cash Dividend for ISIN IE00077FRP95`, so the ISIN *is* the counterparty
- [x] Monthly savings-plan executions of the same instrument do not collide in the dedupe check — same amount, same
      counterparty, different date must stay distinct bookings
- [x] Transfers between the Giro account and the Tagesgeld account can be marked per 032; nothing in this ticket marks them
      automatically
- [x] Unit tests over synthetic extracted text: row parsing, securities lines, interest, balance reconciliation match and
      mismatch, refusal of a foreign layout
- [x] Env-gated harness parses a real statement from a path in an environment variable; no document is committed
- [ ] Verified once that securities charges on a real **ING** Giro statement already arrive as bookings, so the claim in the
      resolution holds
- [x] `make check` green

## Scope correction from the real document
`TRANSAKTIONSÜBERSICHT` on page 2 is **not** a securities table: it is the money-market sweep of idle cash
(`Kauf`/`Verkauf` of `BNP Paribas InstiCash`). Its rows mirror the cash rows that triggered them — the 38,71 € interest
payment of 01 Juli returns as a 38,71 € fund purchase on 02 Juli, the 1.000,00 € transfer of 17 Juli as a purchase the
same day. Importing both would count the statement twice and break the balance reconciliation, so only
`UMSATZÜBERSICHT` is read. Confirmed with the user; how to take the sweep in anyway is recorded in `decisions.md` and in
the doc comment of `trade_republic_layout.dart`.

## How it was built
- `PositionedWord` and the band grouping moved from `ing_giro_layout.dart` into `pdf/positioned_word.dart` — a second
  parser is what makes them shared. `monthNamesDe` in `core/format/date_format.dart` became public: reading `01 Juli 2026`
  needs the same list that formats it
- Direction comes from the running `SALDO` column (`balance − previous balance`), not from which of the two amount columns
  a number sits in: `ZAHLUNGSEINGANG` at x=368.7 and `ZAHLUNGSAUSGANG` at x=422.8 are close and their values
  right-aligned, so a boundary between them would have been the most fragile part of the parse. The printed amount is then
  checked against the balance step, and a disagreement is reported per row
- Three things the geometry dump corrected against the first draft: amounts arrive with the currency inside one word
  (`38,71 €`), a row's date wraps to `01 Juli` 3.8pt above the baseline and `2026` 3.8pt below it (so the band tolerance
  has to exceed 3.8, not the 3.0 the ING parser uses), and a wrapped description line shares the x of the line above it —
  which made `groupIntoBands` sort words in reading order instead of by `left` alone. Without that last fix the transfer
  row read `Outgoing (DE0750…) transfer for Lukas Kochniss` and the payee fell back to the type
- Verified against the real statement: 7 bookings, sum −93707 cents, closing balance 2134471, no warnings

## Open
- The ING cross-check. Needs a real Giro statement carrying a securities charge:
  `ING_PDF=/pfad/auszug.pdf flutter test test/tool/ing_geometry_dump_test.dart` — the charge has to show up as an ordinary
  booking in the dumped rows

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
