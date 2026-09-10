# Split a Picnic PDF at its `Hinzugefügt am` sections

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 061 |
| **Status** | Draft |

## Description
A Picnic order can be added to after it was placed, and each part is charged separately — so one document describes several
bookings. Ticket 057 dropped section parsing on 2026-08-25, but for a **photo**: the receipt is far too long for one
screenshot, so the user crops per day instead. That reasoning does not apply to the PDF, which arrives whole and whose text
layer is readable in the test VM (`decisions.md`, 2026-08-17). Sections are therefore parseable here, and 057 stays as it is —
its subject is the booking as a plausibility bound, which is PDF-independent and still needed (see below).

Wanted: a scan of such a PDF offers the rows of **one** section — the one belonging to the booking it is attached to — instead
of every row of the whole delivery.

## What the dump says
`test/tool/receipt_pdf_dump_test.dart` over a real 5-page document, 2026-09-08, coordinates in
`.claude/tmp/picnic_pdf_words.tsv` (gitignored; page numbers below are 1-based, the TSV's `page` column is 0-based).

**The heading is real and geometrically distinguishable.** `Hinzugefügt am <Wochentag> <d> <Monat>` at `x 175.1`, word height
**12.0** against a median word height of **8.0**. Twice in the document: page 1 `top 381.0` and page 4 `top 387.0`. It is a
heading, **not** a column — the reading that motivated this ticket was mistaken about that, which the dump settles.

**The key is the order number, not the date.** Both headings read `Hinzugefügt am Sonntag 6 September` — the *same* date. One
line below each sits `Bestellnr` with a different value: `803-708-1345` and `904-498-1574`. Splitting on the date would merge
the two sections. So the date is unusable as a key inside the document, before the PayPal shift against the booking date even
enters the picture.

**No subtotal is printed per section.** The document carries exactly one `Zwischensumme` (128,79 €, page 4) and one
`Gesamtbetrag` (120,91 €, page 5), both at the end. A section's subtotal has to be **summed from its rows**, and can be
compared against nothing printed.

**Deposits and taxes are global.** `Pfand` / `Flaschen` / `Tüten`, `Eingereichtes Pfand` and `Mwst 7% / 19%` all sit behind the
last section. Nothing is allocated per section, so a computed section subtotal can never exactly equal a booking amount that
carries its share of the deposit. **The subtotal is a hint, not a checksum** — which is why 057's rule stands: the booking
stays the only external figure, and 019's Restposten closes the rest.

**The section sizes are lopsided.** Counting the quantity column (`x ≈ 148.9`): 48 rows in the document, of which the second
section holds **exactly one** (page 4, `top 451.5`, 2 units). The rest belong to the first section, plus the undelivered row
at `top 738.0` that 061 removes.

## Open questions, to be settled during refinement
- **Is there ever a section without a heading?** Both sections of this document carry `Hinzugefügt am`, so the original order
  is not visible as an unlabelled first block — either it is absent here or the first heading covers it. A split rule that
  assumes "every section has a heading" is unverified until a document with an un-added original order has been dumped. Not to
  be guessed: assuming layout without a dump is exactly how 045 produced a fix that did not survive a real photo.
- **How does the user choose the section?** Candidates: pick the section whose summed subtotal comes closest to the booking
  amount (automatic, but ambiguous when two sections are similar, and skewed by the global deposit), or offer the sections as
  a choice labelled with `Bestellnr` and subtotal (one tap, no guessing). The one-row second section above suggests the
  automatic match is more fragile than it sounds.
- **Does `Bestellnr` deserve to be stored?** It would make an import idempotent per part, but the scan path writes an
  `ImportedSource` with a document hash already (009/016), and one hash for a document that yields several imports is exactly
  the collision to think through before adding a field.

## Acceptance Criteria
- [ ] A section boundary is recognised from the `Hinzugefügt am` heading plus its `Bestellnr` line, by geometry and not by a
      sender vocabulary — heading height against the document's median is the signal, in the spirit of `decisions.md`
      (2026-08-21)
- [ ] The date is **not** used to distinguish sections, and a test pins the real case of two sections sharing one date
- [ ] Each section reports its own summed subtotal, and no mismatch banner is raised against it — it is not a printed total
      (057)
- [ ] A document without any heading behaves exactly as today: one section, nothing changes
- [ ] The rows the review offers belong to the chosen section only, and the choice mechanism is whatever refinement decides
- [ ] Global blocks (deposit, taxes, `Zwischensumme`, `Gesamtbetrag`) belong to no section — 061 already keeps them out of the
      positions, this ticket must not reintroduce them as members of the last one
- [ ] The fixture is generated from the real dump's coordinates, and pins two sections with one shared date, their row counts
      (one of them a single row) and their subtotals
- [ ] `make check` green

## Out of Scope
- Everything 061 owns: the `Zwischensumme` terminator, the undelivered rows, the deposit
- Splitting a **photo** into sections — 057's reframe stands, a screenshot cannot hold the document
- Matching a section to a booking by date; the dump shows the date does not distinguish them

## Affected Tests
- `pdf_receipt_parser` suites for the section split, on the real dump's coordinates
- The scan flow, if the section choice reaches the review screen

## Fixtures Needed
No committed PDF (`decisions.md`, 2026-08-10/11). Real coordinates transcribed from `.claude/tmp/picnic_pdf_words.tsv`.

### Refinement Tokens (estimate)
- Input: ~7k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
_Filled after Done._
