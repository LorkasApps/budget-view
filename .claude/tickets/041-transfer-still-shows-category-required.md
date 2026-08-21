# A transfer still shows the category field as required

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | None |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Severity** | Low |
| **Status** | Draft |

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

## Open questions for refinement
- Does the marker just disappear for a transfer, or does the label change to say the category is optional?
- The same field also carries the suggestion marker and its count (014). Do those still make sense on a transfer, given the
  learn hook now skips transfers entirely — arguably a transfer should not display a suggestion at all
- Does the import preview's category row need the same treatment, or does it never claim to be required?

## Acceptance Criteria
_Not refined yet._

## Affected Tests
- The transaction form tests around the required category; `manual_entry_category_required_test.dart` must keep asserting the
  requirement for a **regular** booking

## Fixtures Needed
No.

## Token Usage
_Filled after Done._
