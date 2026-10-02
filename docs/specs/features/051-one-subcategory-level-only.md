# Only one sub-category level

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | None |
| **Status** | In Progress |

## Description
The category tree is free-depth today: a category may hang under any other, and `buildCategoryTree` recurses as far as the
data goes. Wanted: **exactly two levels** — roots and their children, nothing below.

The second half of the request is the payoff: with the rule in place the parent selection in the category form shrinks from
"every category except my own subtree" to "one of the roots", and several places that exist only to handle depth get simpler
or disappear.

## What the rule touches
| Place | Today | With the rule |
|-------|-------|---------------|
| `CategoryFormScreen` parent picker | every non-archived category minus `ineligibleParents` | the roots only — and no parent at all for a category that already has children |
| `ineligibleParents` (`domain/category_tree.dart`) | itself plus all descendants, to prevent cycles | a cycle needs three levels; with two, "not a child, not myself" is the whole rule |
| Quick-create in the picker (026) | the per-row `+` creates a child of any row | must be off on a row that is already a child, or it creates a third level |
| `CategoryTreeScreen` | expandable tree, reorder within siblings | at most one expand level; reorder across levels is already refused |
| `pickCategory` + its search (038) | "a hit pulls its whole subtree, at any depth" | the same rule, but "any depth" is now one |
| Rollup, drilldown, line-item resolver | walk a subtree of unknown depth | unchanged in code, shallower in practice |

## Resolved during refinement
- **The repository enforces it** with a `CategoryInvalid`, and the UI prevents it before that. Structural invariants live there
  already — unique name per parent, the delete guard, the cycle protection — while the form owns input rules like the category
  requirement (`decisions.md`, 2026-08-12). Practical reason too: quick-create in the picker (026) writes straight through the
  repository, so a UI-only rule would leave exactly that path as the hole a third level slips through
- **Existing deeper data is left alone**; only new violations are refused. `buildCategoryTree` tolerates any depth, dev data is
  wiped anyway, a migration would silently move the user's categories and a read-time refusal would make the app unusable
  against data it stored itself
- **`ineligibleParents` goes.** It computes "myself plus all descendants" to prevent cycles, and with two levels a cycle cannot
  exist. The form offers `findRoots()` minus itself instead — the reduction this ticket was asked for, helper and tests included
- **A category that already has children keeps a disabled parent field with a reason** (`Hat Unterkategorien — kann selbst keine
  werden`). Hiding it would make the form look different per category and provoke the question where it went; a disabled field
  explains the rule where it applies
- **Eligibility is decided on the stored `parentUuid`, not on the filtered tree.** `buildCategoryTree` promotes a category whose
  parent is archived or absent to a root, so a child *looks* like a root in the picker. If it could take children there, the tree
  would be two levels on screen and three in the data — and restoring the archived parent would produce exactly the depth the
  repository forbids. So a parent is only choosable when it has `parentUuid == null` itself, archived or not, and the per-row `+`
  stays off on a promoted child. Visible consequence, deliberately: a promoted child sits at root level but accepts no children —
  it *is* not a root, its parent is merely hidden

## Acceptance Criteria
- [x] `CategoryRepository.save` throws `CategoryInvalid` when the chosen parent itself has a parent — archived or not.
      `findByUuid` ignores `archived`, so the archived case needs no special path
- [x] The category form offers only roots as parents, minus the category itself
- [x] A category with children has a disabled parent field carrying the reason
- [x] The per-row `+` in the picker is absent on any row whose stored `parentUuid` is set, including a promoted child
- [x] `ineligibleParents` is deleted, and nothing references it — `_wouldCycle` went with it, see below
- [x] `CategoryTreeScreen` shows at most one expand level; reorder across levels stays refused as today — **emergent, no code
      change.** A hard cap in the view would hide the third level of data the next AC promises to keep rendering, so the cap
      stays a write rule and the view keeps asking `hasChildren`
- [x] Existing three-level data still renders and is not modified. `buildCategoryTree` is untouched, and the user confirmed
      on 2026-10-02 that no three-level data exists anyway, so this costs nothing in practice
- [x] The picker search of 038 keeps working; its three-level fixture becomes two, and the loss is noted in that ticket rather
      than silently dropped
- [x] `make check` green — 690 passed, 6 skipped (2026-10-02), against 681 before

## How it was built
**The rule is checked on both sides, which the ACs did not ask for.** AC 1 covers only the parent side: "the chosen parent
must not itself have a parent". Moving a category that *has* children under a root produces depth three just as well, from
below. The form disables its field in that case, but the form is not the enforcement point — quick-create writes straight
through `save`. So `save` also refuses when the category being given a parent has children. One extra query, and only when a
parent is being set. Recorded as **ADR 0155**.

Archived categories count on both sides: `findByUuid` ignores `archived` and `findChildren` returns archived children, so
hiding a category never frees up a level.

**`_wouldCycle` went too.** Once the parent must be a root, the ancestor walk can only ever be one step long, and the
self-parent case is checked separately — the whole method was unreachable. The ticket only named `ineligibleParents`, but both
existed for the same reason, which is the reduction the ticket was asked for.

**AC 2 and 3 had no test at all** — no form test file existed. New: `category_form_parent_test.dart`, five tests. `items` is
not a public field on `DropdownButtonFormField`, so the offered options are read the way a user sees them: open the menu and
assert the texts, following `transfer_target_picker_test.dart`.

**One failure on the way in, worth remembering.** Flattening the search fixture meant the path test had to search a child
instead of a grandchild — and searching `Getränke` makes `find.text('Getränke')` match twice, because the search field holds
the query too. The trap is documented in `category.md` for `CategoryTreeScreen`; it reaches the picker as soon as the query
*is* the name being asserted. Fixed with `find.widgetWithText(ListTile, …)`.

## Out of Scope
- Any change to how a line item inherits its category (012)
- Merging or moving existing categories in bulk
- A migration or a read-time refusal for deeper data

## Affected Tests
As built:
- `category_tree_test.dart` — the two `ineligibleParents` tests deleted; its three-level fixtures stay, because they test
  the read path's depth tolerance, which AC 7 requires
- `category_repository_test.dart` — the cycle test renamed to the rule it now actually proves, plus four: archived child as
  a parent, a category with children being given one, an archived child still blocking, and a root still being accepted
- `category_form_parent_test.dart` — **new file**, five tests for AC 2 and 3
- `category_picker_quick_create_test.dart` — the `Getränke` tooltip flipped to `findsNothing`, plus a child row and a
  promoted child both carrying no `+`
- `category_picker_search_test.dart` — fixture flattened, six tests retargeted

## Fixtures Needed
No. Two- and three-level trees built inline, plus an archived parent for the promotion case.

## Device check
Both changes are visible but narrow, and the widget tests cover them at 1200 px. What they cannot see is the extra line the
helper text adds under the parent field.

- [ ] `Kategorien` → a category **with** subcategories: the parent field is greyed out and reads
      `Hat Unterkategorien — kann selbst keine werden`, and the field below it is not pushed off screen
- [ ] A category **without** subcategories: the field is usable and offers only root categories plus `Keine (Wurzel)`
- [ ] In a category picker (e.g. on a booking), a subcategory row carries no `+` while a root row still does

### Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
- Input: ~45k tokens
- Output: ~9k tokens
