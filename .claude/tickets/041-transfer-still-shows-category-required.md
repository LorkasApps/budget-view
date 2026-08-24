# A transfer still shows the category field as required

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | None |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Severity** | Low |
| **Status** | Ready |

## Description
Ticket 032 dropped the category requirement for a transfer, and saving one without a category works. But the booking form
still paints the category field with its red required hint, so the form says "you must" while the app says "you need not".

Cosmetic — nothing is blocked and nothing is wrong in the data. It is the kind of inconsistency that makes a user distrust
the next message the form shows them, which is why it is worth fixing rather than living with.

## Repro Steps
1. Open a booking, switch **Umbuchung** on
2. Look at the category field: the required marker stays
3. Save — it succeeds

## Expected vs Actual
- **Expected:** with `Umbuchung` on, the category field presents itself as optional
- **Actual:** it still presents itself as required, while the save path no longer enforces it

## Affected Envs
`dev`, `prod` — the widget renders the same everywhere.

## Workaround
Ignore the marker; saving works.

## Since When
Since ticket 032 (2026-08-21). The conditional rule landed in `TransactionValidation.category` and in `_save`, but not in
the field's own decoration.

## Resolved during refinement
- **Wording** → with `Umbuchung` on, the required marker and the red `Pflichtfeld` text go and the label becomes
  `Kategorie (optional)`; with it off, the field is required as today. Follows the convention of the same form, where every
  optional field spells it out (`Notiz (optional)`, `Zahlungsempfänger / Absender (optional)`) — dropping only the marker
  would leave the category as the one field that says nothing either way. Accepted cost: this label changes while the form
  is open, which no other label does

- **Suggestion marker** → hidden while `Umbuchung` is on, count included. The learn hook skips transfers, so accepting such
  a suggestion teaches nothing, and the category it offers is evaluated by no report. Rejected keeping it (a category *is*
  legal on a transfer, so someone setting one by hand might want the hint) because a marker that neither learns nor counts
  toward anything is the same kind of misleading hint this ticket removes

- **Import preview** → the suggestion rule comes along, the required rule has nothing to fix. The preview never claims the
  category is required (`decisions.md`, 2026-08-12: the requirement sits in the form, the PDF import allows uncategorised
  rows), but a row can be marked `Umbuchung` there too (`pdf_import_screen.dart:701`), and then the marker promises the same
  learning that does not happen. So: marker hidden on a row marked as a transfer, everything else in the preview untouched

## Acceptance Criteria
- [ ] Booking form with `Umbuchung` **on**: no required marker, no red `Pflichtfeld` text, and the label reads
      `Kategorie (optional)`
- [ ] Booking form with `Umbuchung` **off**: label reads `Kategorie`, marker and validation exactly as today
- [ ] Toggling `Umbuchung` back and forth flips the label both ways and never clears a category the user already picked
- [ ] The suggestion marker and its count are hidden while `Umbuchung` is on, and return when it is switched off
- [ ] Import preview: a row marked `Umbuchung` shows no suggestion marker and no count; its category chip stays usable, and
      the row's category is not cleared by the marking
- [ ] Import preview: nothing about the required behaviour changes — an uncategorised row stays importable
- [ ] Saving a transfer without a category still succeeds; saving a **regular** booking without one is still refused
- [ ] `make check` green

## Affected Tests
- The transaction form tests around the required category; `manual_entry_category_required_test.dart` must keep asserting the
  requirement for a **regular** booking
- New: the label and the hidden marker under `Umbuchung`, in the form and in the import preview
- `import_preview_suggest_test.dart` — its suggestion assertions must keep holding for rows that are not transfers

## Fixtures Needed
No.

### Refinement Tokens (estimate)
- Input: ~11k tokens
- Output: ~1.5k tokens

### Implementation Tokens (estimate)
_Filled after Done._
