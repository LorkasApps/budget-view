# Only one sub-category level

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | None |
| **Status** | Ready |

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
- [ ] `CategoryRepository.save` throws `CategoryInvalid` when the chosen parent itself has a parent — archived or not
- [ ] The category form offers only roots as parents, minus the category itself
- [ ] A category with children has a disabled parent field carrying the reason
- [ ] The per-row `+` in the picker is absent on any row whose stored `parentUuid` is set, including a promoted child
- [ ] `ineligibleParents` is deleted, and nothing references it
- [ ] `CategoryTreeScreen` shows at most one expand level; reorder across levels stays refused as today
- [ ] Existing three-level data still renders and is not modified
- [ ] The picker search of 038 keeps working; its three-level fixture becomes two, and the loss is noted in that ticket rather
      than silently dropped
- [ ] `make check` green

## Out of Scope (proposed, to confirm)
- Any change to how a line item inherits its category (012)
- Merging or moving existing categories in bulk

## Affected Tests
- `category_tree_test.dart` (tree building, `ineligibleParents`), the category form tests around the parent picker,
  `category_picker_quick_create_test.dart` for the per-row `+`, and `category_picker_search_test.dart`, whose fixture is a
  deliberately three-level tree and would have to become two
- Repository tests if enforcement lands there

## Fixtures Needed
No. Two- and three-level trees built inline, plus an archived parent for the promotion case.

### Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
_Filled after Done._
