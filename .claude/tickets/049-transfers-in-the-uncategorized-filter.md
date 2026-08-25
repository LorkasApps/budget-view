# Transfers clog the "only uncategorized" filter

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | None |
| **Domain** | Transaction |
| **Blocked By** | 053 (its fix lands there) |
| **Severity** | Low |
| **Status** | Draft |

## Description
The booking list carries a `Nur ohne Kategorie` filter (`transaction_list_screen.dart:43`), whose purpose is "what still
needs a category". Since ticket 032 a transfer legitimately has none, and ticket 041 spells that out in the form, so every
transfer ever marked sits in that filter forever. The list of open work never empties, which makes the filter useless for
the one thing it is for.

The report is **not** affected: transfers fall out before the rollup (`decisions.md`, 2026-08-21), so its `Ohne Kategorie`
row already ignores them.

## Repro Steps
1. Mark a booking as `Umbuchung`, leave its category empty, save
2. Open the booking list and switch on `Nur ohne Kategorie`
3. The transfer is listed

## Expected vs Actual
- **Expected:** the filter shows only bookings that could still get a category — transfers are not among them
- **Actual:** transfers appear, permanently

## Affected Envs
`dev`, `prod` — the filter is the same everywhere.

## Workaround
Give the transfer a category, which then shows in a report that excludes it anyway.

## Since When
Since ticket 032 (2026-08-21) dropped the category requirement for transfers. The filter was not revisited then.

## Resolved during refinement (2026-08-25)
Folded into ticket **053**, which replaces the `Nur ohne Kategorie` toggle with a category filter whose `Ohne Kategorie`
option carries this rule. Kept as its own entry rather than deleted: it records an observed defect with a repro, and if 053
is ever rescoped or postponed the finding would otherwise be lost. Closes when 053 lands.

## Open questions for refinement
- Does a transfer that *does* carry a category still show in the unfiltered list as today? (Presumably yes — this ticket is
  only about the filter)
- Is the filter's label still right, or should it say what it excludes?
- Does the same reasoning apply anywhere else a "missing category" is counted or badged?

## Acceptance Criteria
Owned by 053: `Ohne Kategorie` lists no transfers, while a regular booking without a category is still listed.

## Affected Tests
- The booking-list filter tests: a transfer without a category is absent under `Nur ohne Kategorie`, a regular booking
  without one is still present

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
