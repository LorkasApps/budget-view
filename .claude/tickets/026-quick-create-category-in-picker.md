# Quick-create a category from the picker

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | None (010 + 011 already `Done`) |
| **Status** | Ready |

## Description
A missing category currently costs the user the whole entry: there is no way in from `pickCategory`, so the only route is cancel the form → back to the account list → category icon → FAB → create → start the entry again. The typed input is lost on the way.

The fix belongs in `pickCategory` itself, not in the callers: the sheet is used from **four** places (booking form, inline quick-pick in the transaction list, PDF import preview, line-item sheet), so one entry point covers all of them.

**Decided up front:** quick creation, not the full `CategoryFormScreen`. Name plus a pre-filled parent, everything else defaulted. Icon and colour stay editable later in the tree screen — offering the 24-icon grid and 12-colour palette mid-entry would rebuild the form the user just escaped from.

## Resolved during refinement
- **Parent source** → explicit, never guessed. Every tree row carries a trailing `+` meaning "new subcategory here", and
  one `Neue Kategorie` row near the top (below the none-option) creates at root level. The parent is fixed by the gesture and is not
  editable inside quick-create. Chosen because tapping a row already means "select this one", so the parent needs its own
  gesture, and because a parent field would mean a second picker sheet stacked on the first. Accepted cost: busier rows,
  and the `+` hit area has to stay clearly separate from the selection tap
- **Form factor** → an `AlertDialog` over the open sheet: title names the parent (`Neue Unterkategorie in Lebensmittel`,
  or `Neue Kategorie` at root), one name field, `Abbrechen` / `Anlegen`. Rejected the inline-expanding row (keyboard,
  autoscroll and sheet height would have to cooperate on a row that may sit deep in the scrolled tree) and a stacked
  second sheet (two similar dismiss gestures, and the space it buys is space the ticket deliberately does not want)
- **Name collision** → refused, shown as a field error from `CategoryInvalid`; the dialog stays open and nothing is
  written. No "select the existing one instead" shortcut: the rule and its message already exist in the repository, and
  the colliding sibling is visible in the tree behind the dialog anyway
- **Row order in the sheet** → the none-option (`Keine Kategorie` / `Erbt von der Buchung …`) keeps the first slot,
  because the `null` vs `CategoryPick(null)` distinction is load-bearing. `Neue Kategorie` sits directly below it,
  separated by a divider, so the two are not read as one group

## Acceptance Criteria
- [ ] Every row of the `pickCategory` tree carries a trailing `+` that starts quick-create with that row as parent
- [ ] One `Neue Kategorie` row below the none-option (divider between them) starts quick-create at root level
- [ ] The `+` and the row's selection tap have separate hit areas; tapping the row still selects, never creates
- [ ] Quick-create is an `AlertDialog` naming its parent, with a single name field and `Abbrechen` / `Anlegen`
- [ ] Icon defaults to `label`, colour to `#607D8B`, `sortOrder` per the entity default — no icon grid, no palette
- [ ] Persists through `CategoryRepository.save`; no new domain logic and no new repository method
- [ ] `CategoryInvalid` (empty name, duplicate sibling name) renders as a field error inside the dialog; the dialog stays
      open and nothing is written
- [ ] On success the sheet closes and returns the new category as the pick, so the caller needs no second tap
- [ ] Works from all four call sites, since it lives in the shared sheet: booking form, inline quick-pick in the
      transaction list, PDF import preview, line-item sheet
- [ ] In the line-item case the none-option keeps its `Erbt von der Buchung (…)` label and its first position
- [ ] Nothing about `CategoryTreeScreen` or `CategoryFormScreen` changes
- [ ] `manual_entry_category_required_test.dart` still passes: the added rows must not introduce a clear-option
- [ ] `make check` green

## Affected Tests
- `test/features/category/presentation/category_picker_quick_create_test.dart` — trailing `+` present per row and
  parented correctly, root entry present, create flow returns the new category as the pick, duplicate-name rejection
  stays inside the dialog, row tap still selects instead of creating
- Existing picker tests must keep passing: `manual_entry_category_required_test.dart` asserts that no clear-option appears for manual entry, so an added row must not break that expectation

## Fixtures Needed
No. A two-root tree with one child plus one colliding sibling, built inline in the test — same call as 024 and 025.

### Refinement Tokens (estimate)
- Input: ~24k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
_Filled after Done._
