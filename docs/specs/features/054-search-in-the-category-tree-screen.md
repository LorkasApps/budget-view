# Search in the category overview

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | None (038 shipped the filter this reuses) |
| **Status** | Done |

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
- [x] A search field narrows the tree through `filterCategoryTree`, unchanged from 038 — a hit keeps its subtree, the path to it
      stays visible, case-insensitive substring, umlauts literal
- [x] While a query is active the drag handles are gone and the screen says why
- [x] Clearing the query brings the handles back and restores the full tree
- [x] With the show-archived toggle off, no archived category appears in a result; with it on, they do
- [x] The visible-children count is unaffected by the query
- [x] Long-press still archives from a filtered row, with the existing refusal when children exist
- [x] `filterCategoryTree` itself is untouched, and the 038 picker tests stay green
- [x] `make check` green

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
- Input: ~55k tokens
- Output: ~7k tokens
- Delegated: a Sonnet sub-agent wrote the test file but died on an API error
  before reporting; its output was verified by hand and kept

## How it was built
Two traps sat between the refined decisions and the ACs, both found while reading
the screen rather than while running it:

- **The path to a hit would have been invisible.** `filterCategoryTree` keeps
  non-matching ancestors as the path, but `flattenVisible` only descends into
  nodes in the expanded set — and this screen starts collapsed. So while a query
  is active every node is treated as expanded, the way the picker already does
  it. `_expanded` itself is never touched by a query, which is what lets clearing
  the search restore the previous collapse state.
- **`N Unterkategorien` would have shrunk.** For a node kept only as a path,
  `filterCategoryTree` rebuilds it with its children pruned, so
  `node.children.length` counts matches rather than children. The subtitle now
  counts off the unfiltered list. `_delete` takes that same count, so its refusal
  states the real number too; the refusal *condition* is unchanged, archived
  children still being the repository's business alone.

Two choices beyond what the ticket settled:

- **While searching the list is a plain `ListView`**, not a `ReorderableListView`
  with its handles hidden. That widget also exposes reorder through semantics
  actions, so hiding the handle alone would have left sorting reachable on a
  filtered list — the exact thing the refinement decided against.
- **The expand chevrons go too**, since everything is expanded already and a
  toggle that visibly does nothing is worse than no toggle.

Testing note for whoever comes next: on this screen `find.text('<name>')` matches
twice once a query is typed, because the search field holds that text as well.
The suite uses `find.widgetWithText(ListTile, name)`. Seven tests failed on this
before it was understood — the finder, not the screen, was wrong.
