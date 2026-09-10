# Trade Republic import refuses a statement: row without a readable date

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Severity** | High |
| **Status** | Done |

## Description
Importing a Trade Republic statement fails with `Seite 1: Zeile ohne lesbares Datum`. That warning comes from
`parseTradeRepublicStatement`: a band carried two or more amounts, so it was read as a booking row, but `_parseDate` found no
day, month and year among its date-column words.

The consequence is not just one missing row. A dropped row breaks the reconciliation against `ENDSALDO − ANFANGSSALDO`, and
ticket 040 deliberately made that refuse the whole statement rather than import a half-read one. So one unreadable date costs
the entire import.

## Repro Steps
1. Buchung → Import → pick a Trade Republic cash statement (the one that failed, handed over out of band)
2. The preview reports `Seite 1: Zeile ohne lesbares Datum` and no bookings are offered

## Expected vs Actual
- **Expected:** every row of the cash table parses, or the failure names a row a human can find on the paper
- **Actual:** one row's date is unreadable, and the statement is refused entirely

## Cause — not the hypothesis, something simpler
**Trade Republic abbreviates the month.** The failing statement covers April 2024 and prints `10 Apr.` / `2024`, while the
statement 040 was verified against covers July and prints `01 Juli`. `_parseDate` compared the token against `monthNamesDe`
for equality, so `Apr.` was not a month, the date stayed incomplete and the row was dropped — which then broke the
reconciliation and refused the document.

The abbreviation hits `Jan.`, `Feb.`, `Mär.`, `Apr.`, `Aug.`, `Sept.`, `Okt.`, `Nov.`, `Dez.` — while `Mai`, `Juni` and `Juli`
are short enough to be printed in full. So the bug was live in eight months of the year and invisible in three, and the one
verified statement happened to fall in the three. The glued-token hypothesis was wrong.

## Fix
`_monthOf` matches a month by **prefix** after stripping a trailing period, requiring at least three letters and refusing an
ambiguous prefix. Three letters are unambiguous across the twelve German names (`Jun`/`Jul` and `Mär`/`Mai` differ by then),
two would not be.

Verified against the real April 2024 statement through the harness: two bookings, `2024-04-10` and `2024-04-22`, sum 620000
cents equal to the closing balance, no warnings.

Nebenbefund worth keeping: this document's columns sit at different x than January's (`TYP` at 110.5 versus 113.2,
`BESCHREIBUNG` at 155.1 versus 157.8). Deriving the columns from each page's header instead of hard-coding them, decided in
040, absorbed that without a line of change.

## Affected Envs
`dev`, `prod` — the parser is the same everywhere.

## Workaround
Enter the affected bookings by hand, or import the month from the Giro side if the same movements appear there.

## Since When
Since ticket 040 (2026-08-24). The parser was verified against one statement, and its date handling was built from that one
statement's word split.

## Affected Tests
- `trade_republic_layout_test.dart`: `10 Apr.` and `22 Sept.` parse, and a word that is not a month at all still leaves the
  row unread with its warning. The full-name fixtures from 040 stay green

## Fixtures Needed
No committed document. The abbreviated month, transcribed from the real statement.

### Refinement Tokens (estimate)
- Input: ~6k tokens
- Output: ~1k tokens

### Implementation Tokens (estimate)
- Input: ~25k tokens
- Output: ~3k tokens
