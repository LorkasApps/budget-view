# A Picnic PDF counts undelivered products and the deposit as positions

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Severity** | Medium |
| **Status** | Draft |

## Description
A real Picnic PDF (5 pages, text layer present) was pushed through `test/tool/receipt_pdf_dump_test.dart` on 2026-09-08. The
parser reads 39 positions summing **129,10 €** against a printed `Gesamtbetrag` of **120,91 €** — the checksum warning fires,
and two of those rows document no purchase at all.

This is independent of the section feature (062): it happens on every Picnic PDF, section-aware or not.

## What the dump says
Word coordinates from `.claude/tmp/picnic_pdf_words.tsv` (gitignored, does not persist — the fixture built from it is the
artifact that stays; same handling as 055's OCR dump). **Page numbers below are 1-based**, the dump's `page` column is
0-based: the `Zwischensumme` row is `page 3` in the TSV.

**The document has a clean terminator.** `Zwischensumme` (page 4, `top 617.4`) closes the item list at **128,79 €**. Everything
below it belongs to the invoice, not to the basket:

| Page | `top` | Content | Value |
|------|-------|---------|-------|
| 4 | 507–554 | `Pfand` / `Flaschen` / `Tüten` | 4,89 € = 4,50 € + 0,39 € |
| 4 | 617 | `Zwischensumme` | 128,79 € |
| 4 | 668–695 | `Hoppla, etwas ist schiefgegangen. Leider können wir diese Produkte nicht liefern.` | — |
| 4 | 736–744 | one article row, sub-line `Ersatz und Geld zurück` | 3,90 € |
| 4 | 794 | `Eingereichtes Pfand` | 0,39 € |
| 5 | 114–141 | `Pfand-tastisch! Danke, dass du deine Tüten abgegeben hast.` | — |
| 5 | 192 | `Gesamtbetrag` | 120,91 € |
| 5 | 225–255 | `Mwst 7% (€75.48)` / `Mwst 19% (€29.89)` | 5,xx € each |

**Two rows the parser keeps that it should not:**

1. **`Pfand 4,89 €` becomes a position.** It is the deposit block's own total (`Flaschen 4,50` + `Tüten 0,39`), printed as a
   summary row, not as an article. Whether the deposit is *money the user paid* is a separate question — see below.
2. **The undelivered article becomes a position.** `Hoppla …` announces products that could not be delivered; the row beneath
   it costs 3,90 € and carries the sub-line `Ersatz und Geld zurück`. The same article also appears as a real position earlier
   (`Gut&Günstig Orangenlimonade 6 x 1,5L`, also 3,90 €), so the document lists it twice — once bought, once refunded.

**The arithmetic, and what it leaves open.** Reported: `sum 12910`, `printed total 12091`, `credits 39`,
`expected position sum 12130`, `MISMATCH by 780`. `Eingereichtes Pfand 0,39` is read correctly as the credit (043's rule
working). Dropping both rows above gives `12910 − 489 − 390 = 12031`, which is **0,99 € under** the expected 121,30 €.
Dropping only the undelivered row leaves 3,90 € over. So the two obvious defects do not add up to the 7,80 € on their own,
and the residue is **not** to be guessed:

- the first task of this ticket is a row-by-row reconciliation of the 39 candidates against the dump, which decides whether a
  real 0,99 € article is missing, read twice, or whether the deposit belongs into the sum after all
- `Zwischensumme 128,79 − Gesamtbetrag 120,91 = 7,88 €`, which is close to the 7,80 € mismatch but not equal to it. That gap
  is a lead, not an explanation

## Open question, to be settled during refinement
**Is a charged deposit a position or not?** The user pays the 4,89 €, and `Gesamtbetrag` appears to include it, so simply
dropping the row may be wrong — it would make the positions fall short of the booking and grow the Restposten (019) by the
deposit. The alternative is one deposit position labelled from the document. `decisions.md` (2026-08-21) settles the opposite
direction only: `Eingereichtes Pfand` is a **credit**, subtracted from the expected sum, never a position.

## Acceptance Criteria
- [ ] `Zwischensumme` terminates the item list: no row printed below it becomes a position
- [ ] The `Hoppla …` block and its `Ersatz und Geld zurück` row are out of the positions, and their article is still present
      **once** — as the row that was actually bought
- [ ] `Pfand` / `Flaschen` / `Tüten` do not become article positions; whatever the refinement decides about the charged
      deposit is implemented deliberately and written into this ticket
- [ ] The 39 candidates are reconciled row by row against the dump, and the 0,99 € residue is explained rather than absorbed
- [ ] `Eingereichtes Pfand` keeps working as a credit (043) — a regression test pins it
- [ ] The rule is a **terminator plus geometry**, not a growing skip vocabulary: 055 showed a misspelled label defeats a word
      list, and `decisions.md` (2026-08-21) rejected vocabulary for page furniture on the PDF path
- [ ] The fixture is built from the real dump's coordinates, generated rather than typed, like 055's
- [ ] `make check` green

## Out of Scope
- Section splitting and per-section subtotals — that is 062
- The OCR path: this document has a text layer, and its summary vocabulary (`Zwischensumme`, `Gesamtbetrag`) differs from the
  app-screenshot receipt of 055 (`Bestellung`, `Gespart`, `Betrag`, `Endsumme`). Whether the OCR skip list needs these words
  too is only worth asking once a photo of *this* layout exists

## Affected Tests
- `pdf_receipt_parser` suites: a fixture from the real dump, plus the existing synthetic cases which must stay green
- Whatever covers `creditCents` today, so the credit rule is not traded away for the terminator

## Fixtures Needed
No committed PDF (`decisions.md`, 2026-08-10/11). Real coordinates transcribed from `.claude/tmp/picnic_pdf_words.tsv`.

### Refinement Tokens (estimate)
- Input: ~6k tokens
- Output: ~1.5k tokens

### Implementation Tokens (estimate)
_Filled after Done._
