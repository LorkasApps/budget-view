# Trade Republic import refuses a statement: row without a readable date

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Severity** | High |
| **Status** | Draft |

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

## Leading hypothesis
The date is parsed **token by token**: a word matching `\d{1,2}` is the day, a word in `monthNamesDe` the month, a word
matching `\d{4}` the year. That assumes the extractor hands over `01`, `Juli`, `2026` as three words, which is what the
January statement's dump showed.

The same document class already proves the extractor glues things: an amount arrives as **one** word including its currency
(`38,71 €`), which is why `_toCents` strips a trailing `€`. If a date arrives glued as `01 Juli` — or the month wraps
differently in a month with a longer name — no token matches any of the three patterns and the whole date is lost.

If that holds, the fix is to join the date column and read it with one pattern
(`(\d{1,2})\s+(\p{L}+)\s+(\d{4})`) instead of classifying tokens, which is both more robust and shorter.

Second candidate, cheaper to rule out than to argue about: the band tolerance of 5.0 chains transitively, so two dense rows can
merge into one band — that would produce a *wrong* date rather than none, but the dump will say.

## Evidence needed
- [ ] The full warning line, including the row text it quotes in `"…"` — that is the band, verbatim
- [ ] The statement itself, out of band, and a harness run:
      `TR_PDF=/pfad/auszug.pdf flutter test test/tool/trade_republic_geometry_dump_test.dart`
      It prints the warnings and writes the per-word geometry, which is exactly what decided the three layout questions of 040

## Affected Envs
`dev`, `prod` — the parser is the same everywhere.

## Workaround
Enter the affected bookings by hand, or import the month from the Giro side if the same movements appear there.

## Since When
Since ticket 040 (2026-08-24). The parser was verified against one statement, and its date handling was built from that one
statement's word split.

## Affected Tests
- `trade_republic_layout_test.dart` gains the real glued shape as a fixture. Its current date fixture uses three separate
  words, taken from the January dump — evidently not the only shape that occurs

## Fixtures Needed
No committed document. The real word split, transcribed from the dump.

## Token Usage
_Filled after Done._
