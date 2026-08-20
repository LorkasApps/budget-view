# Import preview: reach the row category from the edit dialog

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Status** | Ready |

## Description
Auto-tagging fills categories in the import preview from learned rules, and it is sometimes wrong — which is the learning
process working, not a defect. What is missing is the correction path in the place the user is already in.

The per-row edit dialog offers expense/income, amount, description, counterparty and date. The category is **not** in it.
The row's `CategoryChip` does open the picker, so changing a category is possible — but the user editing a row looks for
it in the dialog they just opened, and a suggested-but-wrong category is exactly the reason they opened it.

Clearing is a legal outcome here — import rows may be persisted uncategorized, unlike manual entry where a category is
required. It also already works from the chip; see the resolution below, which is what shrank this ticket to the dialog.

## Resolved during refinement
- **The capability already exists.** `pdf_import_screen.dart` calls `pickCategory` with `allowNone: true`, both per row
  (`_pickRowCategory`) and for `Für alle` (`_pickCategoryForAll`). Changing a category works today, and so does clearing
  it — `Keine Kategorie` in that sheet, which `setRowCategory(index, null)` then applies. A bulk clear exists for the same
  reason. What was missing is the **place**: the user looked in the edit dialog, because that is where a row gets corrected
- **Fix** → the edit dialog gains a category row that opens the same picker and shows the current selection. Deliberately
  duplicating an interaction that already exists on the row chip: two entry points for one action is normally worth
  avoiding, here it matches where people look. Nothing about the chip changes
- **Clearing teaches nothing, by construction.** `learnFrom` requires a set category, so a cleared row creates no rule.
  The consequence is worth stating: the wrong rule keeps its `hitCount` and will suggest again next import. Negative
  learning ("this rule is wrong") would be its own feature and is out of scope here
- **Fixtures** → none. Rows with and without a suggestion are built inline, as `import_preview_suggest_test.dart` does

## Acceptance Criteria
- [ ] The per-row edit dialog carries a category row showing the row's current category, or `Keine Kategorie` when unset
- [ ] Tapping it opens `pickCategory` with `selected` prefilled and `allowNone: true`, exactly as the row chip does
- [ ] The result goes through `ImportFlowController.setRowCategory`, so the suggestion flag is cleared the same way as via
      the chip — an override from the dialog must be indistinguishable from an override on the row
- [ ] Clearing from the dialog sets the row to no category, and the row then persists uncategorized
- [ ] When the row carries a suggestion, the dialog shows its marker and `<n>×` count, so it is visible *why* a category is
      there before it is replaced
- [ ] Cancelling the dialog changes nothing, including the category
- [ ] Nothing about the row chip, `Für alle`, or the manual entry form changes
- [ ] Widget test: set a category from the dialog, clear it from the dialog, cancel without effect, and that the suggestion
      flag is cleared on override
- [ ] `manual_entry_category_required_test.dart` stays green — no clear option may leak into manual entry
- [ ] `make check` green

## Out of Scope (proposed, to confirm)
- Changing what the learn loop learns; only the correction path in the preview is at stake
- The manual entry form, where a category stays mandatory (`manual_entry_category_required_test.dart` asserts that no
  clear option appears there — it must keep passing)

## Affected Tests
- `test/features/transaction/import/import_preview_suggest_test.dart` — suggestion handling in the preview
- `manual_entry_category_required_test.dart` must stay green: whatever is added here must not leak a clear option into
  manual entry

## Fixtures Needed
No — inline rows in the test, as the existing import suites do.

### Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
_Filled after Done._
