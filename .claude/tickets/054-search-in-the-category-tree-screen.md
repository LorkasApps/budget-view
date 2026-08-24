# Search in the category overview

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | None (038 shipped the filter this reuses) |
| **Status** | Draft |

## Description
`CategoryTreeScreen` shows the whole tree with no way to narrow it down. Ticket 038 gave the *picker* a search and left the
tree screen out on purpose, with a stated reason: the tree screen also carries drag-reorder, and reordering a filtered list is
meaningless. That decision is this ticket.

The filter itself already exists and is pure: `filterCategoryTree(roots, query)` in `domain/category_tree.dart` — a name hit
keeps its whole subtree, non-matching ancestors stay as the path, case-insensitive substring, umlauts literal. Reusing it means
the two searches in the app cannot drift apart.

## The actual question: what happens to reorder
Options, to decide during refinement:

| Option | Consequence |
|--------|-------------|
| Drag handles disappear while a query is active | honest — a partial list has no meaningful order — and the user has to clear the search to sort |
| Handles stay, reorder applies to the visible siblings only | the stored `sortOrder` then depends on what was filtered, which is how a list silently scrambles itself |
| Search and reorder become separate modes | most explicit, most UI for a screen that is otherwise plain |

## Open questions for refinement
- Which of the three above, and does the screen say why the handles went away?
- The screen has a **show-archived** toggle. Does search span archived categories when it is on, and only then?
- The subtitle counts visible children. With a filter active, does it count all children or only the matching ones? Counting
  all is the truthful number about the category; counting matches explains the list — they disagree exactly when it matters
- Long-press archives a category. Does that stay available on a filtered row, or does it wait for a cleared search too?
- Does ticket 051 (one sub-category level) make this smaller? A two-level tree is easier to scan, but a user with thirty roots
  still scrolls — so probably not smaller, just shallower

## Acceptance Criteria
_Not refined yet._

## Out of Scope (proposed, to confirm)
- Changing the matching rule; it is shared with 038 by design
- Searching inside the category form's parent picker, which 051 may reduce to a handful of roots anyway

## Affected Tests
- New tree-screen tests: search narrows, the path to a hit stays visible, whatever happens to reorder is asserted, and the
  archived toggle keeps working under a query
- `category_tree_test.dart` and the 038 picker tests must stay green — the filter itself does not change

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
