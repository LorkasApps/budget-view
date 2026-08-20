# Import preview: change and clear a row's category from the edit dialog

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Status** | Draft |

## Description
Auto-tagging fills categories in the import preview from learned rules, and it is sometimes wrong — which is the learning
process working, not a defect. What is missing is the correction path in the place the user is already in.

The per-row edit dialog offers expense/income, amount, description, counterparty and date. The category is **not** in it.
The row's `CategoryChip` does open the picker, so changing a category is possible — but the user editing a row looks for
it in the dialog they just opened, and a suggested-but-wrong category is exactly the reason they opened it.

Second half: **clearing**. Import rows may be persisted uncategorized, so "no category" is a legal outcome here, unlike
manual entry where a category is required. Whether the preview's picker currently offers that is the first thing
refinement has to establish.

## Open questions for refinement
- Does the preview's `pickCategory` call pass `allowNone: true` today? If yes, clearing already works from the chip and
  this ticket is only about the dialog. If no, the clear path has to be added — and `CategoryPick(null)` versus `null`
  must be handled correctly, since that distinction is load-bearing in the picker
- Should the dialog get a category **field**, or should it simply carry the same chip the row shows? The second is less
  new UI and keeps one interaction to learn
- Does clearing a suggested category also clear the suggestion marker and its `<n>×`, and does it count as an override
  for the learn loop — or as "no opinion"? `ImportFlowController.setRowCategory` clears the suggested flag today; the
  learn hook runs on persist, per row
- `Für alle` bulk-assigns every row. Is there a matching "clear all" wanted, or would that be a foot-gun on a
  77-row statement?
- Anything to fix about the marker itself while in there — 028 flagged that the suggested row's chip plus marker plus
  count is the row that already overflowed once (errors.md)

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Out of Scope (proposed, to confirm)
- Changing what the learn loop learns; only the correction path in the preview is at stake
- The manual entry form, where a category stays mandatory (`manual_entry_category_required_test.dart` asserts that no
  clear option appears there — it must keep passing)

## Affected Tests
- `test/features/transaction/import/import_preview_suggest_test.dart` — suggestion handling in the preview
- `manual_entry_category_required_test.dart` must stay green: whatever is added here must not leak a clear option into
  manual entry

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
