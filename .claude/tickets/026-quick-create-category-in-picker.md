# Quick-create a category from the picker

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | None (010 + 011 already `Done`) |
| **Status** | Draft |

## Description
A missing category currently costs the user the whole entry: there is no way in from `pickCategory`, so the only route is cancel the form → back to the account list → category icon → FAB → create → start the entry again. The typed input is lost on the way.

The fix belongs in `pickCategory` itself, not in the callers: the sheet is used from **four** places (booking form, inline quick-pick in the transaction list, PDF import preview, line-item sheet), so one entry point covers all of them.

**Decided up front:** quick creation, not the full `CategoryFormScreen`. Name plus a pre-filled parent, everything else defaulted. Icon and colour stay editable later in the tree screen — offering the 24-icon grid and 12-colour palette mid-entry would rebuild the form the user just escaped from.

## Acceptance Criteria (draft — not yet locked)
- [ ] `pickCategory` sheet offers a "Neue Kategorie" entry
- [ ] Quick-create asks for the name only; parent is pre-filled, icon defaults to `label`, colour to `#607D8B` (the existing entity defaults)
- [ ] Persists through `CategoryRepository.save` — no new domain logic; `CategoryInvalid` (empty name, duplicate sibling name) is surfaced inline instead of as a snackbar behind the sheet
- [ ] On success the new category is returned as the pick, so the caller is left with it selected and no second tap is needed
- [ ] Reaches all four call sites, since it lives in the shared sheet
- [ ] Nothing about the existing tree screen or `CategoryFormScreen` changes

## Open Questions for Refinement
- **Which parent gets pre-filled?** Root, or the node the user had highlighted when tapping "Neue Kategorie"? The latter is more useful but needs the row's context — and a picker row is currently a plain selection, not a focusable state
- Is the quick-create a second sheet on top, an inline row that expands into a text field, or a small dialog?
- Should the parent be changeable during quick-create, or strictly the pre-filled one (with a "move it later in the tree" nudge)?
- Behaviour when the name collides with an existing sibling: refuse with the repository's message, or offer to select the existing category instead? The second reads friendlier but silently turns a create into a pick
- Does the entry belong at the top of the sheet or below the tree? Top is reachable, bottom keeps the tree the primary content
- Line-item sheet runs the picker with `allowNone: true` and the label "Erbt von der Buchung (…)" — does quick-create sit next to that option without confusing the two?

## Affected Tests
- `test/features/category/presentation/category_picker_quick_create_test.dart` — entry present, create flow returns the new category as the pick, duplicate-name rejection stays inside the sheet
- Existing picker tests must keep passing: `manual_entry_category_required_test.dart` asserts that no clear-option appears for manual entry, so an added row must not break that expectation

## Fixtures Needed
Ask during refinement.
