# Only one sub-category level

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | None |
| **Status** | Draft |

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

## Open questions for refinement
- **Who enforces it?** The repository (a `CategoryInvalid` when the chosen parent is not a root, like the unique-name rule
  and the delete guard) or only the UI? Precedent points at the repository for structural invariants and the form for
  input rules (`decisions.md`, 2026-08-12)
- What happens to categories that are already three levels deep in existing data — refuse them on read, flatten them, or
  leave them and only block new violations? Dev data gets wiped, so this may be a question about nothing
- Does `ineligibleParents` survive at all, or does the form simply offer `findRoots()`?
- A category that already has children: is its parent field disabled, or hidden with a note saying why?
- Does the rule change what "archived" means for a root with children — archiving a root today leaves its children
  reachable as promoted roots (`buildCategoryTree`), which is how they avoid disappearing. With two levels that promotion is
  the only way a child can *become* a root, which may be fine or may need saying explicitly

## Acceptance Criteria
_Not refined yet._

## Out of Scope (proposed, to confirm)
- Any change to how a line item inherits its category (012)
- Merging or moving existing categories in bulk

## Affected Tests
- `category_tree_test.dart` (tree building, `ineligibleParents`), the category form tests around the parent picker,
  `category_picker_quick_create_test.dart` for the per-row `+`, and `category_picker_search_test.dart`, whose fixture is a
  deliberately three-level tree and would have to become two
- Repository tests if enforcement lands there

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
