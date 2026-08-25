# Search in the category overview

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | None (038 shipped the filter this reuses) |
| **Status** | Ready |

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

## Resolved during refinement
- **The drag handles disappear while a query is active**, with a hint saying `Sortieren erst ohne Suche`. Keeping them and
  reordering only the visible siblings would make the stored `sortOrder` depend on what happened to be filtered out: dragging a
  row up in a list that is missing half its neighbours produces positions relative to rows nobody can see, and the list then
  orders itself differently from what was just on screen. That is the kind of defect nobody reads as a defect — only as "the app
  remembers it wrong". Separate search and sort modes would be the most explicit answer and far too much UI for an otherwise
  plain screen; 038 built the picker's search without a mode for the same reason
- **Search spans archived categories only while the show-archived toggle is on.** The toggle decides what the screen is about;
  search narrows what the screen shows. A query that surfaced archived rows against the toggle would override an explicit choice
- **The child count in the subtitle keeps counting all children**, not the matching ones. It is a statement about the category,
  not about the list, and a number that shrinks with a query invites the reading that children were archived or lost
- **Long-press to archive stays available on a filtered row.** Archiving is about one category and needs no context from its
  siblings, unlike ordering
- **051 does not make this smaller.** A two-level tree is easier to scan, but thirty roots still scroll — the search stays worth
  it, just shallower

## Acceptance Criteria
- [ ] A search field narrows the tree through `filterCategoryTree`, unchanged from 038 — a hit keeps its subtree, the path to it
      stays visible, case-insensitive substring, umlauts literal
- [ ] While a query is active the drag handles are gone and the screen says why
- [ ] Clearing the query brings the handles back and restores the full tree
- [ ] With the show-archived toggle off, no archived category appears in a result; with it on, they do
- [ ] The visible-children count is unaffected by the query
- [ ] Long-press still archives from a filtered row, with the existing refusal when children exist
- [ ] `filterCategoryTree` itself is untouched, and the 038 picker tests stay green
- [ ] `make check` green

## Out of Scope (proposed, to confirm)
- Changing the matching rule; it is shared with 038 by design
- Searching inside the category form's parent picker, which 051 may reduce to a handful of roots anyway

## Affected Tests
- New tree-screen tests: search narrows, the path to a hit stays visible, whatever happens to reorder is asserted, and the
  archived toggle keeps working under a query
- `category_tree_test.dart` and the 038 picker tests must stay green — the filter itself does not change

## Fixtures Needed
No. A two-level tree with one archived parent, built inline.

### Refinement Tokens (estimate)
- Input: ~8k tokens
- Output: ~1.5k tokens

### Implementation Tokens (estimate)
_Filled after Done._
